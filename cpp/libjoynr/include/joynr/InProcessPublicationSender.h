/*
 * #%L
 * %%
 * Copyright (C) 2011 - 2013 BMW Car IT GmbH
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
#ifndef INPROCESSPUBLICATIONSENDER_H
#define INPROCESSPUBLICATIONSENDER_H

#include <string>

#include "joynr/PrivateCopyAssign.h"
#include "joynr/Logger.h"
#include "joynr/JoynrExport.h"
#include "joynr/IPublicationSender.h"

namespace joynr
{

class SubscriptionPublication;
class ISubscriptionManager;
class MessagingQos;

/**
 * @brief
 * The InProcessPublicationSender is used to transfer publications from the PublicationManager to
 * the (local) ISubscriptionManager.
 */
class JOYNR_EXPORT InProcessPublicationSender : public IPublicationSender
{
public:
public:
    ~InProcessPublicationSender() override = default;
    explicit InProcessPublicationSender(ISubscriptionManager* subscriptionManager);
    /**
     * @brief
     *
     * @param sourcePartId
     * @param destPartId
     * @param subscriptionId
     * @param publication
     * @param qos
     */
    void sendSubscriptionPublication(const std::string& senderParticipantId,
                                     const std::string& receiverParticipantId,
                                     const MessagingQos& qos,
                                     SubscriptionPublication&& subscriptionPublication) override;

private:
    DISALLOW_COPY_AND_ASSIGN(InProcessPublicationSender);
    ISubscriptionManager* subscriptionManager;
    ADD_LOGGER(InProcessPublicationSender);
};

} // namespace joynr
#endif // INPROCESSPUBLICATIONSENDER_H
