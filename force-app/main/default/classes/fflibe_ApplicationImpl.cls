public class fflibe_ApplicationImpl {
    
    public static final fflib_Application.UnitOfWorkFactory UOW = new fflib_Application.UnitOfWorkFactory();

    public static final fflibe_Application.ServiceFactory SERVICE = new fflibe_Application.ServiceFactory();

    public static final fflibe_Application.SelectorFactory SELECTOR = new fflibe_Application.SelectorFactory();

    public static final fflibe_Application.DomainFactory DOMAIN = new fflibe_Application.DomainFactory(fflibe_ApplicationImpl.SELECTOR);
    
}