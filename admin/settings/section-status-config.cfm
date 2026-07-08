<cfinclude template="/admin/settings/feature-gates.cfm">

<cfif NOT structKeyExists(request, "_sectionStatusConfigLoaded")>
<cfset request._sectionStatusConfigLoaded = true>
<cfscript>
variables.settingsSectionStatuses = request._sectionStatuses = {
    "app-config" = "",
    "admin-permissions" = "BETA",
    "admin-users" = "BETA",
    "admin-roles" = "BETA",
    "user-review" = "BETA",
    "media-config" = "BETA",
    "uhco-api" = "BETA",
    "migrations" = "BETA",
    "rosters" = "BETA",
    "scheduled-tasks" = "ALPHA",
    "import" = "ALPHA",
    "bulk-exclusions" = "ALPHA",
    "uh-sync" = "ALPHA",
    "query-builder" = "ALPHA",
    "workflows" = "",
    "user-permissions" = "BETA",
    "ldap"      = "BETA",
    "test-mode" = "BETA",
    "observability" = "BETA"
};

function getSettingsSectionStatus(required string sectionKey) {
    var key = lCase(trim(arguments.sectionKey));
    var featureState = request.getSettingsFeatureAvailability(key);
    var rawStatus = structKeyExists(variables.settingsSectionStatuses, key) ? uCase(trim(variables.settingsSectionStatuses[key])) : "";
    if (featureState.isDisabled) {
        return "Disabled";
    }

    if (rawStatus EQ "ALPHA") {
        return "Alpha";
    }

    if (rawStatus EQ "BETA") {
        return "Beta";
    }

    return "";
}
</cfscript>
</cfif>
