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
package io.joynr.messaging.routing;

import joynr.ImmutableMessage;

public class DelayableImmutableMessage extends TimedDelayed {
    private final ImmutableMessage message;
    private String recipient;
    private int retriesCount = 0;

    DelayableImmutableMessage(ImmutableMessage message, long delayForMs, String recipient) {
        super(delayForMs);
        this.message = message;
        this.recipient = recipient;

    }

    public DelayableImmutableMessage(ImmutableMessage message, long delayMs, String recipient, int retriesCount) {
        this(message, delayMs, recipient);
        setRetriesCount(retriesCount);
    }

    public ImmutableMessage getMessage() {
        return message;
    }

    public String getRecipient() {
        return recipient;
    }

    public int getRetriesCount() {
        return retriesCount;
    }

    public void setRetriesCount(int retriesCount) {
        this.retriesCount = retriesCount;
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = super.hashCode();
        result = prime * result + ((message == null) ? 0 : message.hashCode());
        result = prime * result + retriesCount;
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (!super.equals(obj))
            return false;
        if (getClass() != obj.getClass())
            return false;
        DelayableImmutableMessage other = (DelayableImmutableMessage) obj;
        if (message == null) {
            if (other.message != null)
                return false;
        } else if (!message.equals(other.message))
            return false;
        if (retriesCount != other.retriesCount)
            return false;
        return true;
    }
}
