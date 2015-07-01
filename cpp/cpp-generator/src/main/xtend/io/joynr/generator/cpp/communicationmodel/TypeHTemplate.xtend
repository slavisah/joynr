package io.joynr.generator.cpp.communicationmodel
/*
 * !!!
 *
 * Copyright (C) 2011 - 2015 BMW Car IT GmbH
 *
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
 */

import io.joynr.generator.cpp.util.JoynrCppGeneratorExtensions
import io.joynr.generator.cpp.util.TemplateBase
import javax.inject.Inject
import org.franca.core.franca.FCompoundType
import io.joynr.generator.util.CompoundTypeTemplate

class TypeHTemplate implements CompoundTypeTemplate{

	@Inject
	private extension JoynrCppGeneratorExtensions

	@Inject
	private extension TemplateBase

	override generate(FCompoundType type)
'''
«val typeName = type.joynrName»
«val headerGuard = ("GENERATED_TYPE_"+getPackagePathWithJoynrPrefix(type, "_")+"_"+typeName+"_H").toUpperCase»
«warning()»
#ifndef «headerGuard»
#define «headerGuard»

«getDllExportIncludeStatement()»

#include <QObject>
#include <QVariantMap>
#include <QList>
#include <QByteArray>
#include "joynr/Util.h"

//include complex Datatype headers.
«FOR member: getRequiredIncludesFor(type)»
	#include "«member»"
«ENDFOR»

«getNamespaceStarter(type)»

class «getDllExportMacro()» «typeName» : public «IF hasExtendsDeclaration(type)»«getExtendedType(type).joynrName»«ELSE»QObject«ENDIF»{
	Q_OBJECT

	«FOR member: getMembers(type)»
		«val membername = member.joynrName»
		«IF isArray(member)»
			Q_PROPERTY(QList<QVariant> «membername» READ get«membername.toFirstUpper»Internal WRITE set«membername.toFirstUpper»Internal)
		«ELSEIF isByteBuffer(member.type)»
			Q_PROPERTY(QByteArray «membername» READ get«membername.toFirstUpper»Internal WRITE set«membername.toFirstUpper»Internal)
		«ELSE»
			«IF isEnum(member.type)»
				Q_PROPERTY(QString «membername» READ get«membername.toFirstUpper»Internal WRITE set«membername.toFirstUpper»Internal)
			«ELSE»
				// https://bugreports.qt-project.org/browse/QTBUG-2151 for why this replace is necessary
				Q_PROPERTY(«getMappedDatatypeOrList(member).replace("::","__")» «membername» READ get«membername.toFirstUpper» WRITE set«membername.toFirstUpper»)
			«ENDIF»
		«ENDIF»
	«ENDFOR»

public:
	//general methods
	«typeName»();
	«IF !getMembersRecursive(type).empty»
	«typeName»(
		«FOR member: getMembersRecursive(type) SEPARATOR","»
			«getMappedDatatypeOrList(member)» «member.joynrName»
		«ENDFOR»
	);
	«ENDIF»
	«typeName»(const «typeName»& «typeName.toFirstLower»Obj);

	virtual ~«typeName»();

	virtual QString toString() const;
	«typeName»& operator=(const «typeName»& «typeName.toFirstLower»Obj);
	virtual bool operator==(const «typeName»& «typeName.toFirstLower»Obj) const;
	virtual bool operator!=(const «typeName»& «typeName.toFirstLower»Obj) const;
	virtual uint hashCode() const;

	//getters
	«FOR member: getMembers(type)»
		«val joynrName = member.joynrName»
		«IF isArray(member)»
			QList<QVariant> get«joynrName.toFirstUpper»Internal() const;
		«ELSEIF isByteBuffer(member.type)»
			QByteArray get«joynrName.toFirstUpper»Internal() const;
		«ELSE»
			«IF isEnum(member.type)»
				QString get«joynrName.toFirstUpper»Internal() const;
			 «ENDIF»
		«ENDIF»
		«getMappedDatatypeOrList(member)» get«joynrName.toFirstUpper»() const;
	«ENDFOR»

	//setters
	«FOR member: getMembers(type)»
		«val joynrName = member.joynrName»
		«IF isArray(member)»
			void set«joynrName.toFirstUpper»Internal(const QList<QVariant>& «joynrName»);
		«ELSEIF isByteBuffer(member.type)»
			void set«joynrName.toFirstUpper»Internal(const QByteArray& «joynrName»);
	 	«ELSE»
			«IF isEnum(member.type)»
				void set«joynrName.toFirstUpper»Internal(const QString& «joynrName»);
			 «ENDIF»
		«ENDIF»
		void set«joynrName.toFirstUpper»(const «getMappedDatatypeOrList(member)»& «joynrName»);
	«ENDFOR»

private:
	//members
	«FOR member: getMembers(type)»
		 «getMappedDatatypeOrList(member)» m_«member.joynrName»;
	«ENDFOR»
	void registerMetatypes();

};

«getNamespaceEnder(type)»

namespace joynr {
template <>
inline QList<«getPackagePathWithJoynrPrefix(type, "::")»::«typeName»> Util::valueOf<QList<«getPackagePathWithJoynrPrefix(type, "::")»::«typeName»>>(const QVariant& variant){
   return «joynrGenerationPrefix»::Util::convertVariantListToList<«getPackagePathWithJoynrPrefix(type, "::")»::«typeName»>(variant.value<QVariantList>());
}
}
«««		https://bugreports.qt-project.org/browse/QTBUG-2151 for why this typedef is necessary
typedef «getPackagePathWithJoynrPrefix(type, "::")»::«typeName» «getPackagePathWithJoynrPrefix(type, "__")»__«typeName»;
Q_DECLARE_METATYPE(«getPackagePathWithJoynrPrefix(type, "__")»__«typeName»)
Q_DECLARE_METATYPE(QList<«getPackagePathWithJoynrPrefix(type, "__")»__«typeName»>)

inline uint qHash(const «getPackagePathWithJoynrPrefix(type, "::")»::«typeName»& key) {
	return key.hashCode();
}

#endif // «headerGuard»
'''
}
