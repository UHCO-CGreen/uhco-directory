component output="false" singleton {

    
    public directory_service function init() {
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
        var usersService = _getDependency("users_service", "cfc.users_service");
        var flagsService = _getDependency("flags_service", "cfc.flags_service");
        var organizationsService = _getDependency("organizations_service", "cfc.organizations_service");
        var addressesService = _getDependency("addresses_service", "cfc.addresses_service");
        var phoneService = _getDependency("phone_service", "cfc.phone_service");
        var imagesService = _getDependency("images_service", "cfc.images_service");
        var academicService = _getDependency("academic_service", "cfc.academic_service");
        var externalIDService = _getDependency("externalid_service", "cfc.externalid_service");
        var accessService = _getDependency("access_service", "cfc.access_service");
        var emailsService = _getDependency("emails_service", "cfc.emails_service");
        var degreesService = _getDependency("degrees_service", "cfc.degrees_service");
        var studentProfileService = _getDependency("studentProfile_service", "cfc.studentProfile_service");
        var bioService = _getDependency("bio_service", "cfc.bio_service");
        var publicationsService = _getDependency("publications_service", "cfc.publications_service");
        var nameResolutionService = _getDependency("nameResolutionService", "cfc.nameResolution_service");

        profile.user        = usersService.getUser( userID ).data;
        profile.flags       = flagsService.getUserFlags( userID ).data;
        profile.organizations = organizationsService.getUserOrgs( userID ).data;
        profile.addresses   = addressesService.getAddresses( userID ).data;
        profile.phones      = phoneService.getPhones( userID ).data;
        profile.images      = imagesService.getImages( userID ).data;
        profile.academic    = academicService.getAcademicInfo( userID ).data;
        profile.externalIDs = externalIDService.getExternalIDs( userID ).data;
        profile.access      = accessService.getAccessForUser( userID ).data;
        profile.emails      = emailsService.getEmails( userID ).data;
        profile.degrees     = degreesService.getDegrees( userID ).data;
        profile.studentProfile = studentProfileService.getProfile( userID ).data;
        profile.residencies = studentProfileService.getResidencies( userID ).data;
        profile.awards      = studentProfileService.getAwards( userID ).data;
        profile.appointments = _getDependency("userAppointments_service", "cfc.userAppointments_service").getAppointments( userID ).data;
        profile.bio         = bioService.getBio( userID ).data;
        profile.clinicalBio = bioService.getBio( userID, "ClinicalBio" ).data;
        profile.publicationProfiles = publicationsService.getPublicationProfiles( userID ).data;
        profile.publications = publicationsService.getUserPublications( userID ).data;
        profile.publicationFetchSummary = publicationsService.getFetchSummary( userID ).data;
        profile.publicationConfig = publicationsService.getPublicationConfig( userID ).data;

        if ( isStruct(profile.user) AND !structIsEmpty(profile.user) ) {
            profile.user["NAMES"] = nameResolutionService.getAllActiveAliasNameEnvelopeForUser(userID);
        }

        if ( !isStruct(profile.studentProfile) ) {
            profile.studentProfile = {};
        }
        profile.studentProfile["HometownFull"] = _buildHometownFull(
            profile.studentProfile.HOMETOWNCITY ?: "",
            profile.studentProfile.HOMETOWNSTATE ?: ""
        );

        if ( !isArray(profile.residencies) ) {
            profile.residencies = [];
        }

        if ( !isArray(profile.appointments) ) {
            profile.appointments = [];
        }

        return profile;
    }

    private string function _buildHometownFull( string hometownCity = "", string hometownState = "" ) {
        var city = trim(arguments.hometownCity ?: "");
        var state = trim(arguments.hometownState ?: "");

        if ( len(city) AND len(state) ) {
            return city & ", " & state;
        }

        return len(city) ? city : state;
    }

    
    public array function listUsers() {
        return _getDependency("users_service", "cfc.users_service").listUsers();
    }

    public array function listUsersForAdminIndex() {
        return _getDependency("users_service", "cfc.users_service").listUsersForAdminIndex();
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
        return _getDependency("users_service", "cfc.users_service").searchUsers(
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

    private any function _getDependency( required string key, required string componentPath ) {
        if ( !structKeyExists(variables, arguments.key) OR !isObject(variables[arguments.key]) ) {
            variables[arguments.key] = createObject("component", arguments.componentPath).init();
        }

        return variables[arguments.key];
    }

}