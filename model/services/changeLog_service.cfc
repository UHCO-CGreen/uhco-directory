component output="false" singleton {

    /**
     * changeLog_service - Central facade for the admin change log feature.
     *
     * Usage pattern in userEditSave_service or any other service:
     *
     *   var groupID   = application.changeLogSvc.beginGroup("user", userID, "Flags", "Flags save");
     *   var before    = application.changeLogSvc.snapshotUserSection(userID, "flags");
     *   // ... perform the actual mutation ...
     *   application.changeLogSvc.finalizeGroupWithUserSection(groupID, userID, "flags", before);
     *
     * For non-user entities (flags defs, app config), use logDirectChange() instead.
     */

    public any function init() {
        variables.dao         = createObject("component", "dao.changeLog_DAO").init();
        variables.revertSvc   = createObject("component", "cfc.changeLog_revert_service").init();

        // Maps userEditSave section names → human-readable labels
        variables.sectionLabels = {
            "general"         : "General Info",
            "uh"              : "UH Fields",
            "bioinfo"         : "Biographical Info",
            "flags"           : "Flags",
            "emails"          : "Emails",
            "phones"          : "Phones",
            "aliases"         : "Aliases",
            "degrees"         : "Degrees",
            "tabdegrees"      : "Degrees",
            "addresses"       : "Addresses",
            "addaddress"      : "Addresses",
            "orgs"            : "Organizations",
            "extids"          : "External IDs",
            "bio"             : "Bio",
            "studentprofile"  : "Student Profile",
            "awards"          : "Awards",
            "residencies"     : "Residencies"
        };

        // Maps section → tables that are snapshotted before/after.
        // multi=true: capture all rows for userID (REPLACE action).
        // multi=false: capture single row for userID (UPDATE/INSERT/DELETE action).
        variables.sectionTableConfig = {
            "general"        : [{ table="Users",            pk="UserID", multi=false }],
            "uh"             : [{ table="Users",            pk="UserID", multi=false }],
            "bioinfo"        : [
                { table="Users",             pk="UserID", multi=false },
                { table="UserAcademicInfo",  pk="UserID", multi=false },
                { table="UserStudentProfile",pk="UserID", multi=false },
                { table="UserBio",           pk="UserID", multi=false }
            ],
            "flags"          : [{ table="UserFlagAssignments",  pk="UserID", multi=true }],
            "emails"         : [{ table="UserEmails",           pk="UserID", multi=true }],
            "phones"         : [{ table="UserPhone",            pk="UserID", multi=true }],
            "aliases"        : [{ table="UserAliases",          pk="UserID", multi=true }],
            "degrees"        : [{ table="UserDegrees",          pk="UserID", multi=true },
                                { table="Users",                pk="UserID", multi=false }],
            "tabdegrees"     : [{ table="UserDegrees",          pk="UserID", multi=true },
                                { table="Users",                pk="UserID", multi=false }],
            "addresses"      : [{ table="UserAddresses",        pk="UserID", multi=true }],
            "addaddress"     : [{ table="UserAddresses",        pk="UserID", multi=true }],
            "orgs"           : [{ table="UserOrganizations",    pk="UserID", multi=true }],
            "extids"         : [{ table="UserExternalIDs",      pk="UserID", multi=true }],
            "bio"            : [{ table="UserBio",              pk="UserID", multi=false }],
            "studentprofile" : [
                { table="UserAcademicInfo",   pk="UserID", multi=false },
                { table="UserStudentProfile", pk="UserID", multi=false },
                { table="UserDegrees",        pk="UserID", multi=true  }
            ],
            "awards"         : [{ table="UserAwards",           pk="UserID", multi=true }],
            "residencies"    : [{ table="UserResidency",        pk="UserID", multi=true }]
        };

        return this;
    }

    // ── Group lifecycle ───────────────────────────────────────────────────────

    /**
     * Opens a new ChangeGroup and returns its GroupID (UNIQUEIDENTIFIER as string).
     * Reads admin context from session scope; falls back to scheduled_task if no session.
     */
    public string function beginGroup(
        required string entityType,
        required string entityID,
        required string section,
        required string description
    ) {
        var ctx = _getAdminContext();
        return variables.dao.createGroup(
            entityType    = arguments.entityType,
            entityID      = toString(arguments.entityID),
            source        = ctx.source,
            changedByID   = ctx.changedByID,
            changedBy     = ctx.changedBy,
            ipAddress     = ctx.ipAddress,
            changeSection = arguments.section,
            description   = arguments.description
        );
    }

    // ── Snapshot helpers for userEditSave ─────────────────────────────────────

    /**
     * Captures the current state of all tables relevant to a userEditSave section.
     * Call this BEFORE the mutation.
     */
    public struct function snapshotUserSection(required numeric userID, required string section) {
        var configs  = _getSectionConfig(arguments.section);
        var snapshot = {};
        for (var cfg in configs) {
            snapshot[cfg.table] = variables.dao.captureTableRows(cfg.table, cfg.pk, arguments.userID);
        }
        return snapshot;
    }

    /**
     * Captures the after state and writes all ChangeLog rows for the group.
     * Call this AFTER the mutation.
     */
    public void function finalizeGroupWithUserSection(
        required string groupID,
        required numeric userID,
        required string section,
        required struct beforeSnapshot
    ) {
        var configs = _getSectionConfig(arguments.section);
        for (var cfg in configs) {
            var afterRows  = variables.dao.captureTableRows(cfg.table, cfg.pk, arguments.userID);
            var beforeRows = structKeyExists(arguments.beforeSnapshot, cfg.table)
                ? arguments.beforeSnapshot[cfg.table]
                : [];

            if (cfg.multi) {
                // REPLACE: whole set changed — store arrays
                variables.dao.insertChange(
                    groupID    = arguments.groupID,
                    tableName  = cfg.table,
                    pkColumn   = cfg.pk,
                    recordID   = toString(arguments.userID),
                    action     = "REPLACE",
                    beforeJSON = serializeJSON(beforeRows),
                    afterJSON  = serializeJSON(afterRows)
                );
            } else {
                // Single-row: UPDATE, INSERT, or DELETE
                var hasBeforeRow = arrayLen(beforeRows) GT 0;
                var hasAfterRow  = arrayLen(afterRows)  GT 0;

                if (!hasBeforeRow AND !hasAfterRow) continue; // nothing happened

                var action      = !hasBeforeRow ? "INSERT" : (!hasAfterRow ? "DELETE" : "UPDATE");
                var beforeJSON  = hasBeforeRow ? serializeJSON(beforeRows[1]) : "";
                var afterJSON   = hasAfterRow  ? serializeJSON(afterRows[1])  : "";

                variables.dao.insertChange(
                    groupID    = arguments.groupID,
                    tableName  = cfg.table,
                    pkColumn   = cfg.pk,
                    recordID   = toString(arguments.userID),
                    action     = action,
                    beforeJSON = beforeJSON,
                    afterJSON  = afterJSON
                );
            }
        }
    }

    // ── Direct change logging (for non-user-section mutations) ────────────────

    /**
     * Logs a change where the caller already has the before and after data.
     * Use for flag definitions, app config, access areas, etc.
     */
    public void function logDirectChange(
        required string groupID,
        required string tableName,
        required string pkColumn,
        required string recordID,
        required string action,
        any beforeData = "",
        any afterData  = ""
    ) {
        var beforeJSON = "";
        var afterJSON  = "";

        if (isStruct(arguments.beforeData) AND structCount(arguments.beforeData) GT 0) {
            beforeJSON = serializeJSON(arguments.beforeData);
        } else if (isArray(arguments.beforeData) AND arrayLen(arguments.beforeData) GT 0) {
            beforeJSON = serializeJSON(arguments.beforeData);
        } else if (isSimpleValue(arguments.beforeData) AND len(trim(arguments.beforeData))) {
            beforeJSON = arguments.beforeData;
        }

        if (isStruct(arguments.afterData) AND structCount(arguments.afterData) GT 0) {
            afterJSON = serializeJSON(arguments.afterData);
        } else if (isArray(arguments.afterData) AND arrayLen(arguments.afterData) GT 0) {
            afterJSON = serializeJSON(arguments.afterData);
        } else if (isSimpleValue(arguments.afterData) AND len(trim(arguments.afterData))) {
            afterJSON = arguments.afterData;
        }

        variables.dao.insertChange(
            groupID    = arguments.groupID,
            tableName  = arguments.tableName,
            pkColumn   = arguments.pkColumn,
            recordID   = arguments.recordID,
            action     = arguments.action,
            beforeJSON = beforeJSON,
            afterJSON  = afterJSON
        );
    }

    // ── Revert ────────────────────────────────────────────────────────────────

    /**
     * Reverts all changes in a group in reverse order, inside a transaction.
     * The revert itself is written as a new ChangeGroup with Source='revert'.
     * Throws on failure; caller should catch and show a user-facing error.
     */
    public void function revertGroup(required string groupID, required numeric revertedByID) {
        var ctx   = _getAdminContext();
        var group = variables.dao.getGroupByID(arguments.groupID);

        if (!structCount(group)) {
            throw(type="Application", message="Change group not found: #arguments.groupID#");
        }
        if (len(trim(group["REVERTEDAT"] ?: ""))) {
            throw(type="Application", message="This change group has already been reverted.");
        }

        variables.revertSvc.revertGroup(
            changeLogDAO  = variables.dao,
            group         = group,
            revertedByID  = arguments.revertedByID,
            revertedBy    = ctx.changedBy
        );
    }

    // ── Query methods (passed through from DAO) ───────────────────────────────

    public array function getGroupsByEntity(required string entityType, required string entityID, numeric maxRows=200) {
        return variables.dao.getGroupsByEntity(argumentCollection=arguments);
    }

    public struct function getAllGroups(
        string  filterEntityType = "",
        string  filterSource     = "",
        string  filterSection    = "",
        numeric filterAdminID    = 0,
        string  dateFrom         = "",
        string  dateTo           = "",
        numeric maxRows          = 100,
        numeric offset           = 0
    ) {
        return variables.dao.getAllGroups(argumentCollection=arguments);
    }

    public struct function getGroupByID(required string groupID) {
        return variables.dao.getGroupByID(arguments.groupID);
    }

    public string function getSectionLabel(required string section) {
        var s = lCase(trim(arguments.section));
        return structKeyExists(variables.sectionLabels, s) ? variables.sectionLabels[s] : arguments.section;
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private struct function _getAdminContext() {
        // Check request scope first (set by scheduled-task detection in Application.cfc)
        var isScheduled = structKeyExists(request, "changeLogSource") AND request.changeLogSource EQ "scheduled_task";

        if (isScheduled) {
            var taskName = structKeyExists(request, "changeLogTaskName") ? request.changeLogTaskName : "Scheduled Task";
            return {
                source      : "scheduled_task",
                changedByID : 0,
                changedBy   : taskName,
                ipAddress   : ""
            };
        }

        // Admin session context
        var adminUserID = 0;
        var adminName   = "Unknown";
        try {
            if (structKeyExists(session, "user") AND isStruct(session.user)) {
                adminUserID = val(session.user.adminUserID ?: 0);
                adminName   = trim((session.user.displayName ?: session.user.username) ?: "");
            }
        } catch (any ignore) {}

        return {
            source      : "admin",
            changedByID : adminUserID,
            changedBy   : adminName,
            ipAddress   : left(trim(cgi.remote_addr ?: ""), 50)
        };
    }

    private array function _getSectionConfig(required string section) {
        var key = lCase(trim(arguments.section));
        return structKeyExists(variables.sectionTableConfig, key)
            ? variables.sectionTableConfig[key]
            : [];
    }

}
