public class fflibe_Application extends fflib_Application {

    @TestVisible 
    private static fflibe_Selector__mdt[] selectorMdt = fflibe_Selector__mdt.getAll().values();
    @TestVisible 
    private static fflibe_Domain__mdt[] domainMdt = fflibe_Domain__mdt.getAll().values();

    
    public class UnitOfWorkFactory extends fflib_Application.UnitOfWorkFactory {
		public UnitOfWorkFactory(List<SObjectType> objectTypes) {
            super(objectTypes);
        }
    }

    // This extension enables you to not require interfaces
    public virtual class ServiceFactory extends fflib_Application.ServiceFactory {
		protected Map<Type, Object> m_serviceTypeToMockServiceImpl;

		/**
		 * Constructs a simple Service Factory
		 **/
		public ServiceFactory() { 
            if (System.Test.isRunningTest()) {
                m_serviceTypeToMockServiceImpl = new Map<Type, Object>();
            }
        }

		/**
		 *   Returns a new instance of the Apex class with the type supplied
		 *   Will return any mock implementation of the interface provided via setMock
		 *
		 * @param serviceType   Apex Service Class
		 * @exception Is thrown if there is no registered Apex class for the interface type
		 **/
		public override Object newInstance(Type serviceType) {
			// Mock implementation?
			if (m_serviceTypeToMockServiceImpl?.containsKey(serviceType) == true)
				return m_serviceTypeToMockServiceImpl.get(serviceType);

			return serviceType.newInstance();
		}

		@TestVisible
		protected override void setMock(Type serviceType, Object serviceImpl) {
			m_serviceTypeToMockServiceImpl.put(serviceType, serviceImpl);
		}
    }

    // this extension utilizes custom metadata instead of a Map to determine which selector class to construct
    public virtual class SelectorFactory extends fflib_Application.SelectorFactory {

		// uses metadata instead of an Apex Map to map SObjectType to Apex Class
		public SelectorFactory() { 
            m_sObjectBySelectorType = new Map<Schema.SObjectType, Type>();
            m_sObjectByMockSelector = new Map<SObjectType, fflib_ISObjectSelector>();
            for (fflibe_Selector__mdt mdt : selectorMdt) {
                m_sObjectBySelectorType.put(
                    ((SObject)Type.forName('Schema', mdt.SObjectApiName__c).newInstance()).getSObjectType() , 
                    Type.forName(mdt.ApexClassName__c)
                );
            }
        }

		@TestVisible // it's called setMock1 because this method may/may not be implemented in your fflib pkg
		protected virtual void setMock1(Schema.SObjectType sobjType, fflib_ISObjectSelector selectorInstance) {
			m_sObjectByMockSelector.put(sobjType, selectorInstance);
		}
	}

    // this extension utilizes custom metadata instead of a Map to determine which domain class to construct
    public virtual class DomainFactory extends fflib_Application.DomainFactory {

        public DomainFactory(fflibe_application.SelectorFactory selectorFactory) {
            super(selectorFactory, new Map<Object, Type>());
            this.setConstructorTypeByObject();
        }

        private void setConstructorTypeByObject() {
            for (fflibe_Domain__mdt mdt : domainMdt) {
                constructorTypeByObject.put(
                    (Object)((SObject)Type.forName('Schema', mdt.SObjectApiName__c).newInstance()).getSObjectType(), 
                    Type.forName(mdt.ApexClassName__c + '.Constructor')
                );
            }
        }

        @TestVisible // it's called setMock1 because this method may/may not be implemented in your fflib pkg
        protected virtual void setMock1(Schema.SObjectType sObjType, fflib_ISObjectDomain mockDomain){
			mockDomainByObject.put((Object) sObjType, (fflib_IDomain) mockDomain);
		}

	}
    
}