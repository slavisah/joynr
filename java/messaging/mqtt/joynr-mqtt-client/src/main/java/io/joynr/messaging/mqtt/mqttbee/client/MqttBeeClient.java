package io.joynr.messaging.mqtt.mqttbee.client;

import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

import org.mqttbee.api.mqtt.datatypes.MqttQos;
import org.mqttbee.api.mqtt.mqtt3.Mqtt3Client;
import org.mqttbee.api.mqtt.mqtt3.message.connect.Mqtt3Connect;
import org.mqttbee.api.mqtt.mqtt3.message.connect.connack.Mqtt3ConnAck;
import org.mqttbee.api.mqtt.mqtt3.message.publish.Mqtt3Publish;
import org.mqttbee.api.mqtt.mqtt3.message.subscribe.Mqtt3Subscribe;
import org.mqttbee.api.mqtt.mqtt3.message.subscribe.Mqtt3Subscription;
import org.mqttbee.api.mqtt.mqtt3.message.unsubscribe.Mqtt3Unsubscribe;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.joynr.messaging.mqtt.IMqttMessagingSkeleton;
import io.joynr.messaging.mqtt.JoynrMqttClient;
import io.reactivex.BackpressureStrategy;
import io.reactivex.Flowable;

/**
 * This implements the {@link JoynrMqttClient} using the mqtt-bee library.
 *
 * Currently mqtt-bee is pre 1.0. Here are a list of things that need doing once the relevant missing
 * feature have been completed in mqtt-bee and we want to make this integration production ready:
 *
 * TODO
 * - Logging is currently implemented proof-of-concept style, needs to be re-worked to be production ready
 * - Re-think how we deal with the various failure scenarios, where we might want to throw exceptions instead of
 *   just logging
 * - Once automatic reconnect feature is available in mqtt-bee, see if this implementation needs to be adapted to
 *   be able to use it
 * - Re-visit setting of QoS levels on subscriptions and publishing, only implemented proof-of-concept style for now
 * - mqtt-bee offers better backpressure handling via rxJava, hence revisit this issue to see how we can make use
 *   of this for our own backpressure handling
 */
public class MqttBeeClient implements JoynrMqttClient {

    private static final Logger logger = LoggerFactory.getLogger(MqttBeeClient.class);

    private final Mqtt3Client client;

    private Consumer<Mqtt3Publish> publishConsumer;

    private IMqttMessagingSkeleton messagingSkeleton;

    private int keepAliveTimeSeconds;

    public MqttBeeClient(Mqtt3Client client, int keepAliveTimeSeconds) {
        this.client = client;
        this.keepAliveTimeSeconds = keepAliveTimeSeconds;
    }

    @Override
    public synchronized void start() {
        logger.info("Initialising MQTT client {} -> {}", this, client);
        while (!client.getClientData().isConnected()) {
            Mqtt3Connect mqtt3Connect = Mqtt3Connect.builder()
                                                    .cleanSession(true)
                                                    .keepAlive(keepAliveTimeSeconds, TimeUnit.SECONDS)
                                                    .build();
            Mqtt3ConnAck mqtt3ConnAck = client.connect(mqtt3Connect)
                                              .doOnSuccess(connAck -> logger.info("MQTT client {} connected: {}.",
                                                                                  client,
                                                                                  connAck))
                                              .doOnError(throwable -> logger.error("Unable to connect MQTT client {}.",
                                                                                   client,
                                                                                   throwable))
                                              .blockingGet();
            if (client.getClientData().isConnected()) {
                logger.info("MQTT client {} connected.", client);
            }
        }
        if (publishConsumer == null) {
            logger.info("Setting up publishConsumer for {}", client);
            Flowable<Mqtt3Publish> publishFlowable = Flowable.create(flowableEmitter -> {
                setPublishConsumer(publish -> flowableEmitter.onNext(publish));
            }, BackpressureStrategy.BUFFER);
            logger.info("Setting up publishing pipeline using {}", publishFlowable);
            client.publish(publishFlowable)
                  .doOnNext(mqtt3PublishResult -> logger.info("Publish result: {}", mqtt3PublishResult))
                  .doOnError(throwable -> logger.error("Publish encountered error.", throwable))
                  .subscribe();
        }
    }

    @Override
    public void setMessageListener(IMqttMessagingSkeleton rawMessaging) {
        this.messagingSkeleton = rawMessaging;
    }

    @Override
    public void shutdown() {
        client.disconnect().blockingAwait();
    }

    @Override
    public void publishMessage(String topic, byte[] serializedMessage) {
        publishMessage(topic, serializedMessage, MqttQos.AT_MOST_ONCE.getCode());
    }

    @Override
    public void publishMessage(String topic, byte[] serializedMessage, int qosLevel) {
        logger.info("Publishing to {} with qos {} using {}", topic, qosLevel, publishConsumer);
        Mqtt3Publish mqtt3Publish = Mqtt3Publish.builder()
                                                .payload(serializedMessage)
                                                .qos(MqttQos.fromCode(qosLevel))
                                                .topic(topic)
                                                .build();
        publishConsumer.accept(mqtt3Publish);
    }

    @Override
    public void subscribe(String topic) {
        logger.info("Subscribing to {}", topic);
        Mqtt3Subscription subscription = Mqtt3Subscription.builder()
                                                          .topicFilter(topic)
                                                          .qos(MqttQos.AT_LEAST_ONCE) // TODO make configurable
                                                          .build();
        Mqtt3Subscribe subscribe = Mqtt3Subscribe.builder().addSubscription(subscription).build();
        client.subscribeWithStream(subscribe)
              .doOnSingle((mqtt3SubAck, sub) -> logger.debug("Subscribed to {} with result {}", sub, mqtt3SubAck))
              .doOnNext(mqtt3Publish -> messagingSkeleton.transmit(mqtt3Publish.getPayloadAsBytes(),
                                                                   throwable -> logger.error("Unable to transmit {}",
                                                                                             mqtt3Publish,
                                                                                             throwable)))
              .subscribe();
    }

    @Override
    public void unsubscribe(String topic) {
        logger.info("Unsubscribing from {}", topic);
        Mqtt3Unsubscribe unsubscribe = Mqtt3Unsubscribe.builder().addTopicFilter(topic).build();
        client.unsubscribe(unsubscribe)
              .doOnComplete(() -> logger.debug("Unsubscribed from {}", topic))
              .doOnError(throwable -> logger.error("Unable to unsubscribe from {}", topic, throwable))
              .subscribe();
    }

    private void setPublishConsumer(Consumer<Mqtt3Publish> publishConsumer) {
        logger.info("Setting publishConsumer to: {}", publishConsumer);
        this.publishConsumer = publishConsumer;
    }
}
