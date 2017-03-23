package io.joynr.messaging.mqtt;

/*
 * #%L
 * %%
 * Copyright (C) 2011 - 2017 BMW Car IT GmbH
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

import javax.inject.Named;

import com.google.inject.AbstractModule;
import com.google.inject.Provides;
import com.google.inject.TypeLiteral;
import com.google.inject.multibindings.MapBinder;
import com.google.inject.multibindings.Multibinder;
import com.google.inject.name.Names;

import io.joynr.messaging.AbstractMiddlewareMessagingStubFactory;
import io.joynr.messaging.IMessaging;
import io.joynr.messaging.IMessagingSkeleton;
import io.joynr.messaging.MessagingSkeletonFactory;
import io.joynr.messaging.routing.GlobalAddressFactory;
import io.joynr.messaging.routing.MessagingStubFactory;
import io.joynr.messaging.routing.MulticastAddressCalculator;
import io.joynr.messaging.serialize.AbstractMiddlewareMessageSerializerFactory;
import io.joynr.messaging.serialize.MessageSerializerFactory;
import joynr.system.RoutingTypes.Address;
import joynr.system.RoutingTypes.MqttAddress;

/**
 * If the {@link io.joynr.messaging.mqtt.MqttModule#PROPERTY_KEY_MQTT_ENABLE_SHARED_SUBSCRIPTIONS} property is set to
 * <code>true</code>, then the shared subscriptions version of the mqtt messaging skeleton is used instead of the
 * default mqtt messaging skeleton.
 *
 * In the case of shared subscriptions we allow load balancing of incoming MQTT messages via the HiveMQ feature of
 * shared subscriptions.
 */
public class MqttModule extends AbstractModule {

    // property key
    public static final String PROPERTY_KEY_MQTT_RECONNECT_SLEEP_MS = "joynr.messaging.mqtt.reconnect.sleepms";
    public static final String PROPERTY_KEY_MQTT_BROKER_URI = "joynr.messaging.mqtt.brokeruri";
    public static final String PROPERTY_KEY_MQTT_CLIENT_ID_PREFIX = "joynr.messaging.mqtt.clientidprefix";
    public static final String PROPERTY_MQTT_ADDRESS = "property_mqtt_address";
    public static final String PROPERTY_KEY_MQTT_KEEP_ALIVE_TIMER_SEC = "joynr.messaging.mqtt.keepalivetimersec";
    public static final String PROPERTY_KEY_MQTT_CONNECTION_TIMEOUT_SEC = "joynr.messaging.mqtt.connectiontimeoutsec";
    public static final String PROPERTY_KEY_MQTT_TIME_TO_WAIT_MS = "joynr.messaging.mqtt.timetowaitms";
    /**
     * Use this key to activate shared subscription support by setting the property's value to <code>true</code>. Shared
     * subscriptions are a feature of HiveMQ which allow queue semantics to be used for subscribers to MQTT topics. That
     * is, only one subscriber receives a message, rather than all subscribers. This feature can be used to load balance
     * incoming messages on MQTT. This feature is useful if you want to run a cluster of JEE nodes while using only MQTT
     * for communication (an alternative is to use the {@link JeeIntegrationPropertyKeys#JEE_ENABLE_HTTP_BRIDGE_CONFIGURATION_KEY HTTP bridge}
     * configuration).
     */
    public static final String PROPERTY_KEY_MQTT_ENABLE_SHARED_SUBSCRIPTIONS = "joynr.messaging.mqtt.enable.sharedsubscriptions";

    @Provides
    @Named(PROPERTY_MQTT_ADDRESS)
    public MqttAddress provideMqttOwnAddress(MqttGlobalAddressFactory globalAddressFactory) {
        return globalAddressFactory.create();
    }

    @Override
    protected void configure() {
        MapBinder<Class<? extends Address>, AbstractMiddlewareMessagingStubFactory<? extends IMessaging, ? extends Address>> messagingStubFactory;
        messagingStubFactory = MapBinder.newMapBinder(binder(), new TypeLiteral<Class<? extends Address>>() {
        }, new TypeLiteral<AbstractMiddlewareMessagingStubFactory<? extends IMessaging, ? extends Address>>() {
        }, Names.named(MessagingStubFactory.MIDDLEWARE_MESSAGING_STUB_FACTORIES));
        messagingStubFactory.addBinding(MqttAddress.class).to(MqttMessagingStubFactory.class);

        MapBinder<Class<? extends Address>, AbstractMiddlewareMessageSerializerFactory<? extends Address>> messageSerializerFactory;
        messageSerializerFactory = MapBinder.newMapBinder(binder(), new TypeLiteral<Class<? extends Address>>() {
        }, new TypeLiteral<AbstractMiddlewareMessageSerializerFactory<? extends Address>>() {
        }, Names.named(MessageSerializerFactory.MIDDLEWARE_MESSAGE_SERIALIZER_FACTORIES));
        messageSerializerFactory.addBinding(MqttAddress.class).to(MqttMessageSerializerFactory.class);

        MapBinder<Class<? extends Address>, IMessagingSkeleton> messagingSkeletonFactory;
        messagingSkeletonFactory = MapBinder.newMapBinder(binder(), new TypeLiteral<Class<? extends Address>>() {
        }, new TypeLiteral<IMessagingSkeleton>() {
        }, Names.named(MessagingSkeletonFactory.MIDDLEWARE_MESSAGING_SKELETONS));
        messagingSkeletonFactory.addBinding(MqttAddress.class).toProvider(MqttMessagingSkeletonProvider.class);

        Multibinder<GlobalAddressFactory<? extends Address>> globalAddresses;
        globalAddresses = Multibinder.newSetBinder(binder(),
                                                   new TypeLiteral<GlobalAddressFactory<? extends Address>>() {
                                                   });
        globalAddresses.addBinding().to(MqttGlobalAddressFactory.class);

        Multibinder<MulticastAddressCalculator> multicastAddressCalculators = Multibinder.newSetBinder(binder(),
                                                                                                       new TypeLiteral<MulticastAddressCalculator>() {
                                                                                                       });
        multicastAddressCalculators.addBinding().to(MqttMulticastAddressCalculator.class);

        bind(MqttClientIdProvider.class).to(DefaultMqttClientIdProvider.class);
    }
}
