component output="false" {

    this.name            = "uhco_dir_api";
    this.sessionManagement = false;   // stateless — no session cookies
    this.setClientCookies  = false;

    public void function onRequestStart( required string targetPage ) {
        cfsetting( showDebugOutput=false );
        // HTTPS enforcement: enable this once an SSL certificate is bound in IIS
        // if (CGI.HTTPS NEQ "on") {
        //     cfheader(name="Location", value="https://" & CGI.HTTP_HOST & CGI.REQUEST_URI);
        //     cfheader(statusCode="301");
        //     abort;
        // }
    }

    public void function onError( required any exception, required string eventName ) {
        cfheader(statusCode="500");
        cfheader(name="Content-Type", value="application/json; charset=utf-8");
        writeOutput(serializeJSON({ error: "Internal server error" }));
        abort;
    }
}
