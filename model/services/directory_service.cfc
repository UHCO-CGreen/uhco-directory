component output="false" singleton {

    
    public directory_service function init() {
        variables.users_service        = createObject("component", "cfc.users_service").init();
        variables.flags_service        = createObject("component", "cfc.flags_service").init();
        variables.organizations_service = createObject("component", "cfc.organizations_service").init();
        variables.addresses_service     = createObject("component", "cfc.addresses_service").init();
        variables.phone_service         = createObject("component", "cfc.phone_service").init();
        variables.images_service        = createObject("component", "cfc.images_service").init();
        variables.academic_service      = createObject("component", "cfc.academic_service").init();
        variables.externalid_service    = createObject("component", "cfc.externalid_service").init();
        variables.access_service        = createObject("component", "cfc.access_service").init();
        variables.emails_service         = createObject("component", "cfc.emails_service").init();
        variables.degrees_service        = createObject("component", "cfc.degrees_service").init();
        variables.studentProfile_service = createObject("component", "cfc.studentProfile_service").init();
        variables.bio_service            = createObject("component", "cfc.bio_service").init();
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
        profile.phones      = variables.phone_service.getPhones( userID ).data;
        profile.images      = variables.images_service.getImages( userID ).data;
        profile.academic    = variables.academic_service.getAcademicInfo( userID ).data;
        profile.externalIDs = variables.externalid_service.getExternalIDs( userID ).data;
        profile.access      = variables.access_service.getAccessForUser( userID ).data;
        profile.emails      = variables.emails_service.getEmails( userID ).data;
        profile.degrees     = variables.degrees_service.getDegrees( userID ).data;
        profile.studentProfile = variables.studentProfile_service.getProfile( userID ).data;
        profile.awards      = variables.studentProfile_service.getAwards( userID ).data;
        profile.bio         = variables.bio_service.getBio( userID ).data;

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