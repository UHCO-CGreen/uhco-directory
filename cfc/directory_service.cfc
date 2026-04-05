component output="false" singleton {

    
    public directory_service function init() {
        variables.users_service        = createObject("component", "dir.cfc.users_service").init();
        variables.flags_service        = createObject("component", "dir.cfc.flags_service").init();
        variables.organizations_service = createObject("component", "dir.cfc.organizations_service").init();
        variables.addresses_service     = createObject("component", "dir.cfc.addresses_service").init();
        variables.images_service        = createObject("component", "dir.cfc.images_service").init();
        variables.academic_service      = createObject("component", "dir.cfc.academic_service").init();
        variables.externalid_service    = createObject("component", "dir.cfc.externalid_service").init();
        variables.access_service        = createObject("component", "dir.cfc.access_service").init();
        return this;
    }


    /**
     * This returns a COMPLETE profile object suitable for:
     * - Modern Campus faculty profiles
     * - Directory listings
     * - Admin management screens
     */
    public struct function getFullProfile( required numeric userID ) {

        var profile = {};

        profile.user        = variables.users_service.getUser( userID ).data;
        profile.flags       = variables.flags_service.getUserFlags( userID ).data;
        profile.organizations = variables.organizations_service.getUserOrgs( userID ).data;
        profile.addresses   = variables.addresses_service.getAddresses( userID ).data;
        profile.images      = variables.images_service.getImages( userID ).data;
        profile.academic    = variables.academic_service.getAcademicInfo( userID ).data;
        profile.externalIDs = variables.externalid_service.getExternalIDs( userID ).data;
        profile.access      = variables.access_service.getAccessForUser( userID ).data;

        return profile;
    }

    
    public array function listUsers() {
        return variables.users_service.listUsers();
    }

    public struct function searchUsers(
        string searchTerm   = "",
        string filterFlag   = "",
        string filterOrg    = "",
        string filterClass  = "",
        string excludeFlags = "",
        string excludeOrgs  = "",
        numeric maxRows     = 50,
        numeric startRow    = 1
    ) {
        return variables.users_service.searchUsers(
            searchTerm   = arguments.searchTerm,
            filterFlag   = arguments.filterFlag,
            filterOrg    = arguments.filterOrg,
            filterClass  = arguments.filterClass,
            excludeFlags = arguments.excludeFlags,
            excludeOrgs  = arguments.excludeOrgs,
            maxRows      = arguments.maxRows,
            startRow     = arguments.startRow
        );
    }

}