/*
 * #%L
 * %%
 * Copyright (C) 2019 BMW Car IT GmbH
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
package io.joynr.messaging.mqtt;

import java.util.Set;

import io.joynr.messaging.JoynrMessageProcessor;
import io.joynr.messaging.RawMessagingPreprocessor;
import io.joynr.statusmetrics.JoynrStatusMetricsAggregator;
import io.joynr.messaging.routing.MessageRouter;
import io.joynr.messaging.routing.RoutingTable;
import joynr.system.RoutingTypes.MqttAddress;

public class SharedSubscriptionsMqttMessagingSkeletonFactory extends AbstractMqttMessagingSkeletonFactory {

    // CHECKSTYLE IGNORE ParameterNumber FOR NEXT 1 LINES
    public SharedSubscriptionsMqttMessagingSkeletonFactory(String[] gbids,
                                                           MqttAddress ownAddress,
                                                           int maxIncomingMqttRequests,
                                                           boolean backpressureEnabled,
                                                           int backpressureIncomingMqttRequestsUpperThreshold,
                                                           int backpressureIncomingMqttRequestsLowerThreshold,
                                                           MqttAddress replyToAddress,
                                                           MessageRouter messageRouter,
                                                           MqttClientFactory mqttClientFactory,
                                                           String channelId,
                                                           MqttTopicPrefixProvider mqttTopicPrefixProvider,
                                                           RawMessagingPreprocessor rawMessagingPreprocessor,
                                                           Set<JoynrMessageProcessor> messageProcessors,
                                                           JoynrStatusMetricsAggregator joynrStatusMetricsAggregator,
                                                           RoutingTable routingTable) {
        super();
        for (String gbid : gbids) {
            mqttMessagingSkeletons.put(gbid,
                                       new SharedSubscriptionsMqttMessagingSkeleton(ownAddress.getTopic(),
                                                                                    maxIncomingMqttRequests,
                                                                                    backpressureEnabled,
                                                                                    backpressureIncomingMqttRequestsUpperThreshold,
                                                                                    backpressureIncomingMqttRequestsLowerThreshold,
                                                                                    replyToAddress.getTopic(),
                                                                                    messageRouter,
                                                                                    mqttClientFactory,
                                                                                    channelId,
                                                                                    mqttTopicPrefixProvider,
                                                                                    rawMessagingPreprocessor,
                                                                                    messageProcessors,
                                                                                    joynrStatusMetricsAggregator,
                                                                                    gbid,
                                                                                    routingTable));
        }
        messagingSkeletonList.addAll(mqttMessagingSkeletons.values());
    }

}
