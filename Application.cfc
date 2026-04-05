component {

    this.name = "UHCO_Directory";
    this.sessionManagement = false; // You can enable if needed
    this.showDebugOutput = true;
    this.cacheTimestamp = now(); // Force recompilation on each application start

    // OPTIONAL: helpful when using /dir/cfc folder
    // this.mappings["/cfc"] = ExpandPath("./cfc");
    public boolean function onApplicationStart() { 
        // Clear any cached data
        StructClear(application);

        // UH API credentials for directory API calls.
        // Prefer environment vars when present, otherwise use local defaults.
        application.uhApiToken = "";
        application.uhApiSecret = "";

        if (structKeyExists(server, "system") AND structKeyExists(server.system, "environment")) {
            if (structKeyExists(server.system.environment, "UH_API_TOKEN")) {
                application.uhApiToken = trim(server.system.environment["UH_API_TOKEN"]);
            }
            if (structKeyExists(server.system.environment, "UH_API_SECRET")) {
                application.uhApiSecret = trim(server.system.environment["UH_API_SECRET"]);
            }
        }

        return true; 
    }
    public boolean function onRequestStart( string targetPage ) {
        return true;
    }

}