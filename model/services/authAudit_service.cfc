component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dao.authAudit_DAO").init();
        return this;
    }

    /**
     * Log an authentication event. Always swallows internally — never lets logging break the auth flow.
     *
     * @source      'admin' or 'userreview'
     * @eventType   LOGIN, LOGIN_FAILED, LOGOUT, TRUSTED_LAUNCH, IMPERSONATE_START, IMPERSONATE_END,
     *              UR_LOGIN, UR_LOGIN_FAILED, UR_LOGOUT, UR_EXTERNAL_AUTH, UR_EXTERNAL_AUTH_FAILED
     * @adminUserID AdminUsers.user_id; omit or 0 for UserReview events and failed logins
     * @username    CougarNet sAMAccountName
     * @ipAddress   cgi.remote_addr (truncated to 50)
     * @userAgent   cgi.http_user_agent (truncated to 500)
     * @details     Free-form context string (truncated to 500)
     */
    public void function log(
        required string source,
        required string eventType,
        numeric adminUserID = 0,
        string username     = "",
        string ipAddress    = "",
        string userAgent    = "",
        string details      = ""
    ) {
        try {
            variables.dao.insertEvent(
                source      = arguments.source,
                eventType   = arguments.eventType,
                adminUserID = arguments.adminUserID,
                username    = arguments.username,
                ipAddress   = arguments.ipAddress,
                userAgent   = arguments.userAgent,
                details      = arguments.details
            );

            try {
                var _payload = {
                    type      = left(trim(arguments.eventType & ""), 30),
                    source    = left(trim(arguments.source & ""), 20),
                    userID    = val(arguments.adminUserID) GT 0 ? int(val(arguments.adminUserID)) : 0,
                    username  = left(trim(arguments.username & ""), 50),
                    timestamp = dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss'Z'"),
                    ip        = left(trim(arguments.ipAddress & ""), 50),
                    details   = left(trim(arguments.details & ""), 500)
                };
                wsPublish("authEvents", serializeJSON(_payload));
            } catch (any ignore) {
                // WebSocket publish is best-effort; swallow silently
            }

        } catch (any ignore) {
            // Never let audit logging break the auth flow
        }
    }

    /**
     * Return the N most recent audit log rows for the observability dashboard.
     */
    public array function getRecentEvents(numeric maxRows = 100) {
        try {
            return variables.dao.getRecentEvents(arguments.maxRows);
        } catch (any ignore) {
            return [];
        }
    }

}
