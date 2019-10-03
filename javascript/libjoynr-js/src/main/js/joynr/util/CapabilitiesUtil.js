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
const DiscoveryEntry = require("../../generated/joynr/types/DiscoveryEntry");
const GlobalDiscoveryEntry = require("../../generated/joynr/types/GlobalDiscoveryEntry");
const DiscoveryEntryWithMetaInfo = require("../../generated/joynr/types/DiscoveryEntryWithMetaInfo");

/**
 * @name CapabilitiesUtil
 * @class
 * @classdesc provides utility functions for dealing with capabilities
 */
const CapabilitiesUtil = {};

/**
 * This method transforms a capabilityInformation into an object of type "DiscoveryEntry"
 *
 * @function
 * @name CapabilitiesUtil#toDiscoveryEntry
 *
 * @param {CapabilityInformation} capabilityInformation the object to be transformed
 *
 * @returns {DiscoveryEntry} the transformed object
 */
CapabilitiesUtil.toDiscoveryEntry = function toDiscoveryEntry(capabilityInformation) {
    return new DiscoveryEntry({
        providerVersion: capabilityInformation.providerVersion,
        domain: capabilityInformation.domain,
        interfaceName: capabilityInformation.interfaceName,
        qos: capabilityInformation.providerQos,
        participantId: capabilityInformation.participantId,
        publicKeyId: capabilityInformation.publicKeyId,
        lastSeenDateMs: Date.now()
    });
};

/**
 * This method transforms an array of capabilityInformations into an array of objects
 * of type DiscoveryEntry
 *
 * @function
 * @name CapabilitiesUtil#toDiscoveryEntries
 *
 * @param {Array} capabilityInformations array of capability information
 *
 * @returns {Array} array of transformed objects of type DiscoveryEntry
 */
CapabilitiesUtil.toDiscoveryEntries = function toDiscoveryEntries(capabilityInformations) {
    const discoveryEntries = [];
    if (capabilityInformations) {
        for (let i = 0; i < capabilityInformations.length; i++) {
            discoveryEntries.push(CapabilitiesUtil.toDiscoveryEntry(capabilityInformations[i]));
        }
    }
    return discoveryEntries;
};

/**
 * This method transforms a DiscoveryEntry into a GlobalDiscoveryEntry
 * with the given address.
 *
 * @function
 * @name CapabilitiesUtil#discoveryEntry2GlobalDiscoveryEntry
 *
 * @param {DiscoveryEntry} discoveryEntry the DiscoveryEntry to be transformed
 * @param {Address} address the address to be used for the GlobalDiscoveryEntry
 *
 * @returns {GlobalDiscoveryEntry} global DiscoveryEntry with provided address
 */
CapabilitiesUtil.discoveryEntry2GlobalDiscoveryEntry = function discoveryEntry2GlobalDiscoveryEntry(
    discoveryEntry,
    address
) {
    return new GlobalDiscoveryEntry({
        providerVersion: discoveryEntry.providerVersion,
        domain: discoveryEntry.domain,
        interfaceName: discoveryEntry.interfaceName,
        participantId: discoveryEntry.participantId,
        qos: discoveryEntry.qos,
        lastSeenDateMs: discoveryEntry.lastSeenDateMs,
        expiryDateMs: discoveryEntry.expiryDateMs,
        publicKeyId: discoveryEntry.publicKeyId,
        address: JSON.stringify(address)
    });
};

/**
 * This method transforms a DiscoveryEntry into a DiscoveryEntryWithMetaInfo
 * with the given isLocal value.
 *
 * @function
 * @name CapabilitiesUtil#convertToDiscoveryEntryWithMetaInfo
 *
 * @param {boolean} isLocal true, if it is a local DiscoveryEntry, false otherwise
 * @param {DiscoveryEntry} discoveryEntry the DiscoveryEntry to be transformed
 *
 * @returns {DiscoveryEntryWithMetaInfo} DiscoveryEntryWithMetaInfo with the given isLocal value
 */
CapabilitiesUtil.convertToDiscoveryEntryWithMetaInfo = function convertToDiscoveryEntryWithMetaInfo(
    isLocal,
    discoveryEntry
) {
    discoveryEntry.isLocal = isLocal;
    return new DiscoveryEntryWithMetaInfo(discoveryEntry);
};

/**
 * This method transforms an array of DiscoveryEntries into an array of objects
 * of type DiscoveryEntryWithMetaInfo
 *
 * @function
 * @name CapabilitiesUtil#convertToDiscoveryEntryWithMetaInfoArray
 *
 * @param {boolean} isLocal true, if the DiscoveryEntries are local DiscoveryEntry, false otherwise
 * @param {Array} discoveryEntries array of DiscoveryEntries
 *
 * @returns {Array} array of transformed objects of type DiscoveryEntryWithMetaInfo with the given isLocal value
 */
CapabilitiesUtil.convertToDiscoveryEntryWithMetaInfoArray = function convertToDiscoveryEntryWithMetaInfoArray(
    isLocal,
    discoveryEntries
) {
    const result = [];
    if (discoveryEntries) {
        for (let i = 0; i < discoveryEntries.length; i++) {
            result.push(CapabilitiesUtil.convertToDiscoveryEntryWithMetaInfo(isLocal, discoveryEntries[i]));
        }
    }
    return result;
};

/**
 * This method generates a key of the currently used format for storage of
 * a capability's participantId in the ParticipantIdStorage
 *
 * @function
 * @name CapabilitiesUtil#generateParticipantIdStorageKey
 *
 * @param {String} domain the domain of the capability that is to be stored
 * @param {String} interfaceName the interface of the capability that is to be stored
 * @param {String} majorVersion the major Version of the capability that is to be stored
 *
 * @returns {String} a key to store the participantId with
 */
CapabilitiesUtil.generateParticipantIdStorageKey = (domain, interfaceName, majorVersion) => {
    return `joynr.participant.${domain}.${interfaceName}.v${majorVersion}`;
};

module.exports = CapabilitiesUtil;