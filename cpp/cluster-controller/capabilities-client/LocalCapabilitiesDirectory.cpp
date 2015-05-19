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
#include "joynr/LocalCapabilitiesDirectory.h"
#include "joynr/infrastructure/IGlobalCapabilitiesDirectory.h"
#include "joynr/infrastructure/IChannelUrlDirectory.h"
#include "joynr/ProxyQos.h"
#include "cluster-controller/capabilities-client/ICapabilitiesClient.h"
#include "joynr/system/ChannelAddress.h"
#include "joynr/exceptions.h"
#include "joynr/CapabilityEntry.h"
#include "joynr/ILocalCapabilitiesCallback.h"
#include "joynr/system/Address.h"
#include "joynr/RequestStatus.h"
#include "joynr/RequestStatusCode.h"
#include "joynr/types/CapabilityInformation.h"
#include "common/InterfaceAddress.h"

#include <QMutexLocker>

namespace joynr
{

using namespace joynr_logging;

Logger* LocalCapabilitiesDirectory::logger =
        Logging::getInstance()->getLogger("MSG", "LocalCapabilitiesDirectory");

const qint64& LocalCapabilitiesDirectory::NO_CACHE_FRESHNESS_REQ()
{
    static qint64 value(-1);
    return value;
}

const qint64& LocalCapabilitiesDirectory::DONT_USE_CACHE()
{
    static qint64 value(0);
    return value;
}

LocalCapabilitiesDirectory::LocalCapabilitiesDirectory(MessagingSettings& messagingSettings,
                                                       ICapabilitiesClient* capabilitiesClientPtr,
                                                       MessageRouter& messageRouter)
        : joynr::system::DiscoveryProvider(joynr::types::ProviderQos(
                  QList<joynr::types::CustomParameter>(), // custom provider parameters
                  1,                                      // provider version
                  1,                                      // provider priority
                  joynr::types::ProviderScope::LOCAL,     // provider discovery scope
                  false                                   // supports on change subscriptions
                  )),
          messagingSettings(messagingSettings),
          capabilitiesClient(capabilitiesClientPtr),
          cacheLock(new QMutex),
          interfaceAddress2GlobalCapabilities(),
          participantId2GlobalCapabilities(),
          interfaceAddress2LocalCapabilities(),
          participantId2LocalCapability(),
          registeredGlobalCapabilities(),
          messageRouter(messageRouter),
          observers()
{
    // setting up the provisioned values for GlobalCapabilitiesClient
    // The GlobalCapabilitiesServer is also provisioned in MessageRouter
    QList<joynr::system::CommunicationMiddleware::Enum> middlewareConnections;
    middlewareConnections.append(joynr::system::CommunicationMiddleware::JOYNR);
    types::ProviderQos providerQos;
    providerQos.setPriority(1);
    this->insertInCache(joynr::system::DiscoveryEntry(
                                messagingSettings.getDiscoveryDirectoriesDomain(),
                                infrastructure::IGlobalCapabilitiesDirectory::getInterfaceName(),
                                messagingSettings.getCapabilitiesDirectoryParticipantId(),
                                providerQos,
                                middlewareConnections),
                        false,
                        true,
                        false);

    // setting up the provisioned values for the ChannelUrlDirectory (domain, interface,
    // participantId...)
    // The ChannelUrlDirectory is also provisioned in MessageRouter  (participantId -> channelId)
    types::ProviderQos channelUrlDirProviderQos;
    channelUrlDirProviderQos.setPriority(1);
    this->insertInCache(
            joynr::system::DiscoveryEntry(messagingSettings.getDiscoveryDirectoriesDomain(),
                                          infrastructure::IChannelUrlDirectory::getInterfaceName(),
                                          messagingSettings.getChannelUrlDirectoryParticipantId(),
                                          channelUrlDirProviderQos,
                                          middlewareConnections),
            false,
            true,
            false);
}

LocalCapabilitiesDirectory::~LocalCapabilitiesDirectory()
{
    // cleanup
    delete cacheLock;
    interfaceAddress2GlobalCapabilities.cleanup(0);
    participantId2GlobalCapabilities.cleanup(0);

    interfaceAddress2LocalCapabilities.cleanup(0);
    participantId2LocalCapability.cleanup(0);
}

void LocalCapabilitiesDirectory::add(joynr::system::DiscoveryEntry& discoveryEntry)
{
    bool isGlobal = discoveryEntry.getQos().getScope() == types::ProviderScope::GLOBAL;

    // register locally
    this->insertInCache(discoveryEntry, isGlobal, true, isGlobal);

    // Inform observers
    informObserversOnAdd(discoveryEntry);

    // register globally
    if (isGlobal) {
        types::CapabilityInformation capInfo(discoveryEntry.getDomain(),
                                             discoveryEntry.getInterfaceName(),
                                             discoveryEntry.getQos(),
                                             capabilitiesClient->getLocalChannelId(),
                                             discoveryEntry.getParticipantId());
        if (!registeredGlobalCapabilities.contains(capInfo)) {
            registeredGlobalCapabilities.append(capInfo);
        }
        this->capabilitiesClient->add(registeredGlobalCapabilities);
    }
}

void LocalCapabilitiesDirectory::remove(const QString& domain,
                                        const QString& interfaceName,
                                        const types::ProviderQos& qos)
{
    // TODO does it make sense to remove any capability for a domain/interfaceName
    // without knowing which provider registered the capability
    QMutexLocker locker(cacheLock);
    QList<CapabilityEntry> entries =
            interfaceAddress2GlobalCapabilities.lookUpAll(InterfaceAddress(domain, interfaceName));
    QList<QString> participantIdsToRemove;

    system::DiscoveryEntry discoveryEntry;

    for (int i = 0; i < entries.size(); ++i) {
        CapabilityEntry entry = entries.at(i);
        if (entry.isGlobal()) {
            registeredGlobalCapabilities.removeAll(
                    types::CapabilityInformation(domain,
                                                 interfaceName,
                                                 qos,
                                                 capabilitiesClient->getLocalChannelId(),
                                                 entry.getParticipantId()));
            participantIdsToRemove.append(entry.getParticipantId());
            participantId2GlobalCapabilities.remove(entry.getParticipantId(), entry);
            interfaceAddress2GlobalCapabilities.remove(
                    InterfaceAddress(entry.getDomain(), entry.getInterfaceName()), entry);
        }
        participantId2LocalCapability.remove(entry.getParticipantId(), entry);
        interfaceAddress2LocalCapabilities.remove(InterfaceAddress(domain, interfaceName), entry);

        convertCapabilityEntryIntoDiscoveryEntry(entry, discoveryEntry);
        informObserversOnRemove(discoveryEntry);
    }
    if (!participantIdsToRemove.isEmpty()) {
        capabilitiesClient->remove(participantIdsToRemove);
    }
}

void LocalCapabilitiesDirectory::remove(const QString& participantId)
{
    QMutexLocker lock(cacheLock);
    CapabilityEntry entry = participantId2LocalCapability.take(participantId);
    interfaceAddress2LocalCapabilities.remove(
            InterfaceAddress(entry.getDomain(), entry.getInterfaceName()), entry);
    if (entry.isGlobal()) {
        participantId2GlobalCapabilities.remove(participantId, entry);
        interfaceAddress2GlobalCapabilities.remove(
                InterfaceAddress(entry.getDomain(), entry.getInterfaceName()), entry);
    }

    system::DiscoveryEntry discoveryEntry;
    convertCapabilityEntryIntoDiscoveryEntry(entry, discoveryEntry);
    informObserversOnRemove(discoveryEntry);

    capabilitiesClient->remove(participantId);
}

bool LocalCapabilitiesDirectory::getLocalAndCachedCapabilities(
        const InterfaceAddress& interfaceAddress,
        const joynr::system::DiscoveryQos& discoveryQos,
        QSharedPointer<ILocalCapabilitiesCallback> callback)
{
    joynr::system::DiscoveryScope::Enum scope = discoveryQos.getDiscoveryScope();

    QList<CapabilityEntry> localCapabilities = searchCache(interfaceAddress, -1, true);
    QList<CapabilityEntry> globalCapabilities =
            searchCache(interfaceAddress, discoveryQos.getCacheMaxAge(), false);

    return callRecieverIfPossible(scope, localCapabilities, globalCapabilities, callback);
}

bool LocalCapabilitiesDirectory::getLocalAndCachedCapabilities(
        const QString& participantId,
        const joynr::system::DiscoveryQos& discoveryQos,
        QSharedPointer<ILocalCapabilitiesCallback> callback)
{
    joynr::system::DiscoveryScope::Enum scope = discoveryQos.getDiscoveryScope();

    QList<CapabilityEntry> localCapabilities = searchCache(participantId, -1, true);
    QList<CapabilityEntry> globalCapabilities =
            searchCache(participantId, discoveryQos.getCacheMaxAge(), false);

    return callRecieverIfPossible(scope, localCapabilities, globalCapabilities, callback);
}

bool LocalCapabilitiesDirectory::callRecieverIfPossible(
        joynr::system::DiscoveryScope::Enum& scope,
        QList<CapabilityEntry>& localCapabilities,
        QList<CapabilityEntry>& globalCapabilities,
        QSharedPointer<ILocalCapabilitiesCallback> callback)
{
    // return only local capabilities
    if (scope == joynr::system::DiscoveryScope::LOCAL_ONLY) {
        callback->capabilitiesReceived(localCapabilities);
        return true;
    }

    // return local then global capabilities
    if (scope == joynr::system::DiscoveryScope::LOCAL_THEN_GLOBAL) {
        if (!localCapabilities.isEmpty()) {
            callback->capabilitiesReceived(localCapabilities);
            return true;
        }
        if (!globalCapabilities.isEmpty()) {
            callback->capabilitiesReceived(globalCapabilities);
            return true;
        }
    }

    // return local and global capabilities
    if (scope == joynr::system::DiscoveryScope::LOCAL_AND_GLOBAL) {
        // return if global entries
        if (!globalCapabilities.isEmpty()) {
            // remove duplicates
            QList<CapabilityEntry> result;
            foreach (CapabilityEntry entry, localCapabilities + globalCapabilities) {
                if (!result.contains(entry)) {
                    result += entry;
                }
            }
            callback->capabilitiesReceived(result);
            return true;
        }
    }

    // return the global cached entries
    if (scope == joynr::system::DiscoveryScope::GLOBAL_ONLY) {
        if (!globalCapabilities.isEmpty()) {
            callback->capabilitiesReceived(globalCapabilities);
            return true;
        }
    }
    return false;
}

void LocalCapabilitiesDirectory::capabilitiesReceived(
        const QList<types::CapabilityInformation>& results,
        QList<CapabilityEntry> cachedLocalCapabilies,
        QSharedPointer<ILocalCapabilitiesCallback> callback,
        joynr::system::DiscoveryScope::Enum discoveryScope)
{
    QMap<QString, CapabilityEntry> capabilitiesMap;
    QList<CapabilityEntry> mergedEntries;

    foreach (types::CapabilityInformation capInfo, results) {
        QList<joynr::system::CommunicationMiddleware::Enum> connections;
        connections.append(joynr::system::CommunicationMiddleware::JOYNR);
        CapabilityEntry capEntry(capInfo.getDomain(),
                                 capInfo.getInterfaceName(),
                                 capInfo.getProviderQos(),
                                 capInfo.getParticipantId(),
                                 connections,
                                 true);
        capabilitiesMap.insertMulti(capInfo.getChannelId(), capEntry);
        mergedEntries.append(capEntry);
    }
    registerReceivedCapabilities(capabilitiesMap);

    if (discoveryScope == joynr::system::DiscoveryScope::LOCAL_THEN_GLOBAL ||
        discoveryScope == joynr::system::DiscoveryScope::LOCAL_AND_GLOBAL) {
        // look if in the meantime there are some local providers registered
        // lookup in the local directory to get local providers which were registered in the
        // meantime.
        mergedEntries += cachedLocalCapabilies;
    }
    callback->capabilitiesReceived(mergedEntries);
}

void LocalCapabilitiesDirectory::lookup(const QString& participantId,
                                        QSharedPointer<ILocalCapabilitiesCallback> callback)
{
    joynr::system::DiscoveryQos discoveryQos;
    discoveryQos.setDiscoveryScope(joynr::system::DiscoveryScope::LOCAL_THEN_GLOBAL);
    // get the local and cached entries
    bool receiverCalled = getLocalAndCachedCapabilities(participantId, discoveryQos, callback);

    // if no reciever is called, use the global capabilities directory
    if (!receiverCalled) {
        // search for global entires in the global capabilities directory
        auto callbackFct = [this, participantId, callback](
                const RequestStatus& status,
                const QList<joynr::types::CapabilityInformation>& result) {
            Q_UNUSED(status);
            this->capabilitiesReceived(result,
                                       getCachedLocalCapabilities(participantId),
                                       callback,
                                       joynr::system::DiscoveryScope::LOCAL_THEN_GLOBAL);
        };
        this->capabilitiesClient->lookup(participantId, callbackFct);
    }
}

void LocalCapabilitiesDirectory::lookup(const QString& domain,
                                        const QString& interfaceName,
                                        QSharedPointer<ILocalCapabilitiesCallback> callback,
                                        const joynr::system::DiscoveryQos& discoveryQos)
{
    InterfaceAddress interfaceAddress(domain, interfaceName);

    // get the local and cached entries
    bool receiverCalled = getLocalAndCachedCapabilities(interfaceAddress, discoveryQos, callback);

    // if no reciever is called, use the global capabilities directory
    if (!receiverCalled) {
        // search for global entires in the global capabilities directory
        auto callbackFct = [this, interfaceAddress, callback, discoveryQos](
                RequestStatus status, QList<joynr::types::CapabilityInformation> capabilities) {
            Q_UNUSED(status);
            this->capabilitiesReceived(capabilities,
                                       getCachedLocalCapabilities(interfaceAddress),
                                       callback,
                                       discoveryQos.getDiscoveryScope());
        };
        this->capabilitiesClient->lookup(domain, interfaceName, callbackFct);
    }
}

QList<CapabilityEntry> LocalCapabilitiesDirectory::getCachedLocalCapabilities(
        const QString& participantId)
{
    return searchCache(participantId, -1, true);
}

QList<CapabilityEntry> LocalCapabilitiesDirectory::getCachedLocalCapabilities(
        const InterfaceAddress& interfaceAddress)
{
    return searchCache(interfaceAddress, -1, true);
}

void LocalCapabilitiesDirectory::cleanCache(qint64 maxAge_ms)
{
    // QMutexLocker locks the mutex, and when the locker variable is destroyed (when
    // it leaves this method) it will unlock the mutex
    QMutexLocker locker(cacheLock);
    interfaceAddress2GlobalCapabilities.cleanup(maxAge_ms);
    participantId2GlobalCapabilities.cleanup(maxAge_ms);
    interfaceAddress2LocalCapabilities.cleanup(maxAge_ms);
    participantId2LocalCapability.cleanup(maxAge_ms);
}

void LocalCapabilitiesDirectory::registerReceivedCapabilities(
        QMap<QString, CapabilityEntry> capabilityEntries)
{
    QMapIterator<QString, CapabilityEntry> entryIterator(capabilityEntries);
    while (entryIterator.hasNext()) {
        entryIterator.next();
        CapabilityEntry currentEntry = entryIterator.value();
        QSharedPointer<joynr::system::Address> joynrAddress(
                new system::ChannelAddress(entryIterator.key()));
        messageRouter.addNextHop(currentEntry.getParticipantId(), joynrAddress);
        this->insertInCache(currentEntry, false, true);
    }
}

// inherited method from joynr::system::DiscoveryProvider
void LocalCapabilitiesDirectory::add(RequestStatus& joynrInternalStatus,
                                     joynr::system::DiscoveryEntry discoveryEntry)
{
    add(discoveryEntry);
    joynrInternalStatus.setCode(joynr::RequestStatusCode::OK);
}

// inherited method from joynr::system::DiscoveryProvider
void LocalCapabilitiesDirectory::lookup(joynr::RequestStatus& joynrInternalStatus,
                                        QList<joynr::system::DiscoveryEntry>& result,
                                        QString domain,
                                        QString interfaceName,
                                        joynr::system::DiscoveryQos discoveryQos)
{
    QSharedPointer<LocalCapabilitiesFuture> future(new LocalCapabilitiesFuture());
    lookup(domain, interfaceName, future, discoveryQos);
    QList<CapabilityEntry> capabilities = future->get();
    convertCapabilityEntriesIntoDiscoveryEntries(capabilities, result);
    joynrInternalStatus.setCode(joynr::RequestStatusCode::OK);
}

// inherited method from joynr::system::DiscoveryProvider
void LocalCapabilitiesDirectory::lookup(joynr::RequestStatus& joynrInternalStatus,
                                        joynr::system::DiscoveryEntry& result,
                                        QString participantId)
{
    QSharedPointer<LocalCapabilitiesFuture> future(new LocalCapabilitiesFuture());
    lookup(participantId, future);
    QList<CapabilityEntry> capabilities = future->get();
    if (capabilities.size() > 1) {
        LOG_ERROR(logger,
                  QString("participantId %1 has more than 1 capability entry:\n %2\n %3")
                          .arg(participantId)
                          .arg(capabilities[0].toString())
                          .arg(capabilities[1].toString()));
    }

    if (!capabilities.isEmpty()) {
        convertCapabilityEntryIntoDiscoveryEntry(capabilities.first(), result);
        joynrInternalStatus.setCode(joynr::RequestStatusCode::OK);
    } else {
        joynrInternalStatus.setCode(joynr::RequestStatusCode::ERROR);
    }
}

// inherited method from joynr::system::DiscoveryProvider
void LocalCapabilitiesDirectory::remove(joynr::RequestStatus& joynrInternalStatus,
                                        QString participantId)
{
    remove(participantId);
    joynrInternalStatus.setCode(joynr::RequestStatusCode::OK);
}

void LocalCapabilitiesDirectory::attach(
        QSharedPointer<LocalCapabilitiesDirectory::IProviderRegistrationObserver> observer)
{
    observers.append(observer);
}

/**
 * Private convenience methods.
 */
void LocalCapabilitiesDirectory::insertInCache(const CapabilityEntry& entry,
                                               bool localCache,
                                               bool globalCache)
{
    QMutexLocker lock(cacheLock);
    InterfaceAddress addr(entry.getDomain(), entry.getInterfaceName());

    // add entry to local cache
    if (localCache) {
        interfaceAddress2LocalCapabilities.insert(addr, entry);
        participantId2LocalCapability.insert(entry.getParticipantId(), entry);
    }

    // add entry to global cache
    if (globalCache) {
        interfaceAddress2GlobalCapabilities.insert(addr, entry);
        participantId2GlobalCapabilities.insert(entry.getParticipantId(), entry);
    }
}

void LocalCapabilitiesDirectory::insertInCache(const joynr::system::DiscoveryEntry& discoveryEntry,
                                               bool isGlobal,
                                               bool localCache,
                                               bool globalCache)
{
    CapabilityEntry entry;
    convertDiscoveryEntryIntoCapabilityEntry(discoveryEntry, entry);
    entry.setGlobal(isGlobal);

    // do not dublicate entries:
    // the combination participantId is unique for [domain, interfaceName, authtoken]
    // check only for local registration: when register in the global cache, a second entry is an
    // update of the age and a refresh
    bool foundMatch = false;
    if (localCache) {
        QList<CapabilityEntry> entryList = searchCache(discoveryEntry.getParticipantId(), -1, true);
        CapabilityEntry newEntry;
        convertDiscoveryEntryIntoCapabilityEntry(discoveryEntry, newEntry);
        entry.setGlobal(isGlobal);
        foreach (CapabilityEntry oldEntry, entryList) {
            if (oldEntry == newEntry) {
                foundMatch = true;
            }
        }
    }

    insertInCache(entry, !foundMatch && localCache, globalCache);
}

QList<CapabilityEntry> LocalCapabilitiesDirectory::searchCache(
        const InterfaceAddress& interfaceAddress,
        const qint64& maxCacheAge,
        bool localEntries)
{
    QMutexLocker locker(cacheLock);

    // search in local
    if (localEntries) {
        return interfaceAddress2LocalCapabilities.lookUpAll(interfaceAddress);
    } else {
        return interfaceAddress2GlobalCapabilities.lookUp(interfaceAddress, maxCacheAge);
    }
}

QList<CapabilityEntry> LocalCapabilitiesDirectory::searchCache(const QString& participantId,
                                                               const qint64& maxCacheAge,
                                                               bool localEntries)
{
    QMutexLocker locker(cacheLock);

    // search in local
    if (localEntries) {
        return participantId2LocalCapability.lookUpAll(participantId);
    } else {
        return participantId2GlobalCapabilities.lookUp(participantId, maxCacheAge);
    }
}

void LocalCapabilitiesDirectory::convertCapabilityEntryIntoDiscoveryEntry(
        const CapabilityEntry& capabilityEntry,
        joynr::system::DiscoveryEntry& discoveryEntry)
{
    discoveryEntry.setDomain(capabilityEntry.getDomain());
    discoveryEntry.setInterfaceName(capabilityEntry.getInterfaceName());
    discoveryEntry.setParticipantId(capabilityEntry.getParticipantId());
    discoveryEntry.setQos(capabilityEntry.getQos());
    discoveryEntry.setConnections(capabilityEntry.getMiddlewareConnections());
}

void LocalCapabilitiesDirectory::convertDiscoveryEntryIntoCapabilityEntry(
        const joynr::system::DiscoveryEntry& discoveryEntry,
        CapabilityEntry& capabilityEntry)
{
    capabilityEntry.setDomain(discoveryEntry.getDomain());
    capabilityEntry.setInterfaceName(discoveryEntry.getInterfaceName());
    capabilityEntry.setParticipantId(discoveryEntry.getParticipantId());
    capabilityEntry.setQos(discoveryEntry.getQos());
    capabilityEntry.setMiddlewareConnections(discoveryEntry.getConnections());
}

void LocalCapabilitiesDirectory::convertCapabilityEntriesIntoDiscoveryEntries(
        const QList<CapabilityEntry>& capabilityEntries,
        QList<system::DiscoveryEntry>& discoveryEntries)
{
    foreach (const CapabilityEntry& capabilityEntry, capabilityEntries) {
        joynr::system::DiscoveryEntry discoveryEntry;
        convertCapabilityEntryIntoDiscoveryEntry(capabilityEntry, discoveryEntry);
        discoveryEntries.append(discoveryEntry);
    }
}

void LocalCapabilitiesDirectory::informObserversOnAdd(const system::DiscoveryEntry& discoveryEntry)
{
    foreach (const QSharedPointer<IProviderRegistrationObserver>& observer, observers) {
        observer->onProviderAdd(discoveryEntry);
    }
}

void LocalCapabilitiesDirectory::informObserversOnRemove(
        const system::DiscoveryEntry& discoveryEntry)
{
    foreach (const QSharedPointer<IProviderRegistrationObserver>& observer, observers) {
        observer->onProviderRemove(discoveryEntry);
    }
}

LocalCapabilitiesFuture::LocalCapabilitiesFuture() : futureSemaphore(0), capabilities()
{
}

void LocalCapabilitiesFuture::capabilitiesReceived(QList<CapabilityEntry> capabilities)
{
    this->capabilities = capabilities;
    futureSemaphore.release(1);
}

QList<CapabilityEntry> LocalCapabilitiesFuture::get()
{
    futureSemaphore.acquire(1);
    futureSemaphore.release(1);
    return capabilities;
}

QList<CapabilityEntry> LocalCapabilitiesFuture::get(const qint64& timeout)
{

    int timeout_int(timeout);
    // prevent overflow during conversion from qint64 to int
    int maxint = std::numeric_limits<int>::max();
    if (timeout > maxint) {
        timeout_int = maxint;
    }

    if (futureSemaphore.tryAcquire(1, timeout_int)) {
        futureSemaphore.release(1);
    }
    return capabilities;
}

} // namespace joynr
