/*
 * #%L
 * %%
 * Copyright (C) 2020 BMW Car IT GmbH
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * #L%
 */
package io.joynr.messaging.mqtt.hivemq.client;

import static com.google.inject.util.Modules.override;
import static org.junit.Assert.assertNotEquals;
import static org.mockito.Matchers.any;
import static org.mockito.Matchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;

import java.util.Arrays;
import java.util.Properties;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.stream.Collectors;

import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.mockito.invocation.InvocationOnMock;
import org.mockito.stubbing.Answer;

import com.google.inject.AbstractModule;
import com.google.inject.Guice;
import com.google.inject.Injector;
import com.google.inject.TypeLiteral;
import com.google.inject.multibindings.Multibinder;
import com.google.inject.name.Names;

import io.joynr.common.JoynrPropertiesModule;
import io.joynr.messaging.ConfigurableMessagingSettings;
import io.joynr.messaging.FailureAction;
import io.joynr.messaging.JoynrMessageProcessor;
import io.joynr.messaging.MessagingPropertyKeys;
import io.joynr.messaging.NoOpRawMessagingPreprocessor;
import io.joynr.messaging.RawMessagingPreprocessor;
import io.joynr.messaging.mqtt.IMqttMessagingSkeleton;
import io.joynr.messaging.mqtt.MqttClientIdProvider;
import io.joynr.messaging.mqtt.MqttModule;
import io.joynr.messaging.routing.MessageRouter;
import io.joynr.messaging.routing.RoutingTable;

public class HivemqMqttClientTest {
    private static final String[] gbids = new String[]{ "testGbid1", "testGbid2" };

    private Injector injector;
    private HivemqMqttClientFactory hivemqMqttClientFactory;
    private String ownTopic;
    @Mock
    private IMqttMessagingSkeleton mockReceiver;
    @Mock
    private MessageRouter mockMessageRouter;
    @Mock
    private RoutingTable mockRoutingTable;
    @Mock
    private MqttClientIdProvider mockMqttClientIdProvider;
    private Properties properties;
    private byte[] serializedMessage;

    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        properties = new Properties();
        properties.put(MqttModule.PROPERTY_MQTT_BROKER_URIS, "tcp://localhost:1883, tcp://localhost:1883");
        properties.put(MqttModule.PROPERTY_KEY_MQTT_CONNECTION_TIMEOUTS_SEC, "60,60");
        properties.put(MqttModule.PROPERTY_KEY_MQTT_KEEP_ALIVE_TIMERS_SEC, "30, 30");
        properties.put(ConfigurableMessagingSettings.PROPERTY_GBIDS,
                       Arrays.stream(gbids).collect(Collectors.joining(",")));
        serializedMessage = new byte[10];

        doAnswer(new Answer<String>() {
            private boolean firstCall = true;

            @Override
            public String answer(InvocationOnMock invocation) throws Throwable {
                if (firstCall) {
                    firstCall = false;
                    return gbids[0];
                }
                return gbids[1];
            }
        }).when(mockMqttClientIdProvider).getClientId();
    }

    private void createHivemqMqttClientFactory() {
        injector = Guice.createInjector(override(new HivemqMqttClientModule()).with(new AbstractModule() {
            @Override
            protected void configure() {
                bind(MqttClientIdProvider.class).toInstance(mockMqttClientIdProvider);
            }
        }), new JoynrPropertiesModule(properties), new AbstractModule() {
            @Override
            protected void configure() {
                bind(MessageRouter.class).toInstance(mockMessageRouter);
                bind(RoutingTable.class).toInstance(mockRoutingTable);
                bind(ScheduledExecutorService.class).annotatedWith(Names.named(MessageRouter.SCHEDULEDTHREADPOOL))
                                                    .toInstance(Executors.newScheduledThreadPool(10));
                bind(RawMessagingPreprocessor.class).to(NoOpRawMessagingPreprocessor.class);
                Multibinder.newSetBinder(binder(), new TypeLiteral<JoynrMessageProcessor>() {
                });
                bind(String[].class).annotatedWith(Names.named(MessagingPropertyKeys.GBID_ARRAY)).toInstance(gbids);
            }
        });

        hivemqMqttClientFactory = injector.getInstance(HivemqMqttClientFactory.class);
    }

    @Test
    public void publishAndReceiveWithTwoClients() throws Exception {
        createHivemqMqttClientFactory();
        ownTopic = "testTopic";
        HivemqMqttClient clientSender = (HivemqMqttClient) hivemqMqttClientFactory.createSender(gbids[0]);
        HivemqMqttClient clientReceiver = (HivemqMqttClient) hivemqMqttClientFactory.createReceiver(gbids[1]);
        assertNotEquals(clientSender, clientReceiver);

        clientReceiver.setMessageListener(mockReceiver);

        clientSender.start();
        clientReceiver.start();

        clientReceiver.subscribe(ownTopic);

        clientSender.publishMessage(ownTopic, serializedMessage);
        verify(mockReceiver, timeout(500).times(1)).transmit(eq(serializedMessage), any(FailureAction.class));

        clientReceiver.unsubscribe(ownTopic);
        clientReceiver.shutdown();
        clientSender.shutdown();
    }
}