component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    /**
     * Write a new active session row and ensure a clean AdminSessionControl row exists
     * (clears any stale ForceLogout flag from a previous session).
     */
    public void function createSession(
        required numeric adminUserID,
        string ipAddress = "",
        string userAgent = ""
    ) {
        // Close any prior active rows for this user before opening a new one.
        // Prevents stale rows from accumulating when sessions end without an
        // explicit logout (browser close, CF restart, session timeout).
        executeQueryWithRetry(
            sql = "
                UPDATE dbo.AdminSessions
                SET    IsActive = 0, LogoutTime = GETUTCDATE(), UpdatedAt = GETUTCDATE()
                WHERE  AdminUserID = :adminUserID AND IsActive = 1
            ",
            params  = { adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );

        executeQueryWithRetry(
            sql = "
                INSERT INTO dbo.AdminSessions (AdminUserID, IPAddress, UserAgent)
                VALUES (:adminUserID, :ipAddress, :userAgent)
            ",
            params = {
                adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer"  },
                ipAddress   = { value = left(trim(arguments.ipAddress & ""), 50),  cfsqltype = "cf_sql_varchar"  },
                userAgent   = { value = left(trim(arguments.userAgent & ""), 500), cfsqltype = "cf_sql_nvarchar" }
            },
            options = { datasource = variables.dsn }
        );

        // Upsert the control row, clearing any prior ForceLogout from a previous session.
        executeQueryWithRetry(
            sql = "
                MERGE dbo.AdminSessionControl AS target
                USING (SELECT :adminUserID AS AdminUserID) AS src
                    ON target.AdminUserID = src.AdminUserID
                WHEN MATCHED THEN
                    UPDATE SET ForceLogout = 0, UpdatedAt = GETUTCDATE()
                WHEN NOT MATCHED THEN
                    INSERT (AdminUserID, ForceLogout, UpdatedAt)
                    VALUES (src.AdminUserID, 0, GETUTCDATE());
            ",
            params = {
                adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    /**
     * Mark all active sessions for a user as logged out.
     * Called from AuthService.logout() and from force-logout.cfm.
     */
    public void function closeSessionsForUser(required numeric adminUserID) {
        executeQueryWithRetry(
            sql = "
                UPDATE dbo.AdminSessions
                SET    IsActive = 0, LogoutTime = GETUTCDATE(), UpdatedAt = GETUTCDATE()
                WHERE  AdminUserID = :adminUserID AND IsActive = 1
            ",
            params = { adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        executeQueryWithRetry(
            sql = "
                UPDATE dbo.AdminSessionControl
                SET    LastLogout = GETUTCDATE(), UpdatedAt = GETUTCDATE()
                WHERE  AdminUserID = :adminUserID
            ",
            params = { adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
    }

    /**
     * Set the ForceLogout flag so the target user is kicked on their next request.
     * Does NOT close the session rows here — onRequestStart does that after detecting the flag.
     */
    public void function setForceLogout(required numeric adminUserID) {
        executeQueryWithRetry(
            sql = "
                MERGE dbo.AdminSessionControl AS target
                USING (SELECT :adminUserID AS AdminUserID) AS src
                    ON target.AdminUserID = src.AdminUserID
                WHEN MATCHED THEN
                    UPDATE SET ForceLogout = 1, UpdatedAt = GETUTCDATE()
                WHEN NOT MATCHED THEN
                    INSERT (AdminUserID, ForceLogout, UpdatedAt)
                    VALUES (src.AdminUserID, 1, GETUTCDATE());
            ",
            params = { adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
    }

    /**
     * Returns true if the ForceLogout flag is set for this user.
     * Called on every admin request from onRequestStart (fast single-row lookup by PK).
     */
    public boolean function checkForceLogout(required numeric adminUserID) {
        var qry = executeQueryWithRetry(
            sql = "
                SELECT ForceLogout
                FROM   dbo.AdminSessionControl
                WHERE  AdminUserID = :adminUserID
            ",
            params = { adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        return qry.recordCount GT 0 AND val(qry.ForceLogout) EQ 1;
    }

    /**
     * Throttled activity ping — update LastActivity in the control row and
     * LastVisitedPath on the most-recent active session row.
     */
    public void function updateLastActivity(required numeric adminUserID, string path = "") {
        executeQueryWithRetry(
            sql = "
                UPDATE dbo.AdminSessionControl
                SET    LastActivity = GETUTCDATE(), UpdatedAt = GETUTCDATE()
                WHERE  AdminUserID = :adminUserID
            ",
            params = { adminUserID = { value = arguments.adminUserID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        executeQueryWithRetry(
            sql = "
                UPDATE TOP (1) dbo.AdminSessions
                SET    LastVisitedPath = :path, UpdatedAt = GETUTCDATE()
                WHERE  AdminUserID = :adminUserID AND IsActive = 1
            ",
            params = {
                adminUserID = { value = arguments.adminUserID,                    cfsqltype = "cf_sql_integer"  },
                path        = { value = left(trim(arguments.path & ""), 500),     cfsqltype = "cf_sql_nvarchar" }
            },
            options = { datasource = variables.dsn }
        );
    }

    /**
     * Returns all currently active admin sessions for the observability dashboard.
     */
    public array function getActiveSessions() {
        var qry = executeQueryWithRetry(
            sql = "
                SELECT
                    s.SessionID,
                    s.AdminUserID,
                    u.cougarnet        AS Username,
                    u.display_name     AS DisplayName,
                    s.LoginTime,
                    s.IPAddress,
                    s.LastVisitedPath,
                    c.LastActivity,
                    s.UpdatedAt
                FROM       dbo.AdminSessions       s
                INNER JOIN dbo.AdminUsers           u ON u.user_id     = s.AdminUserID
                LEFT  JOIN dbo.AdminSessionControl  c ON c.AdminUserID = s.AdminUserID
                WHERE s.IsActive = 1
                ORDER BY s.LoginTime DESC
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

}
