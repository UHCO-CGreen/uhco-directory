<cfscript>
if (!structKeyExists(request, "settingsFeatureAvailability")) {
    request.settingsFeatureAvailability = {};

    request.getSettingsFeatureAvailability = function(required string featureKey) {
        var key = lCase(trim(arguments.featureKey));
        if (structKeyExists(request.settingsFeatureAvailability, key)) {
            return request.settingsFeatureAvailability[key];
        }

        return {
            isDisabled = false,
            label = arguments.featureKey,
            reason = ""
        };
    };
}
</cfscript>