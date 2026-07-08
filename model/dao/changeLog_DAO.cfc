component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    // ── Group management ──────────────────────────────────────────────────────

    public string function createGroup(
        required string  entityType,
        required string  entityID,
        required string  source,
        numeric  changedByID   = 0,
        string   changedBy     = "",
        string   ipAddress     = "",
        string   changeSection = "",
        string   description   = ""
    ) {
        var safeChangedByID = val(arguments.changedByID) GT 0
            ? val(arguments.changedByID)
            : javaCast("null", "");

        var qry = executeQueryWithRetry(
            sql = "
                INSERT INTO dbo.ChangeGroups
                    (EntityType, EntityID, Source, ChangedByID, ChangedBy, IPAddress, ChangeSection, Description)
                OUTPUT INSERTED.GroupID
                VALUES
                    (:entityType, :entityID, :source, :changedByID, :changedBy, :ipAddress, :changeSection, :description)
            ",
            params = {
                entityType    = { value = left(trim(arguments.entityType),    50),  cfsqltype = "cf_sql_varchar"  },
                entityID      = { value = left(trim(arguments.entityID),     100),  cfsqltype = "cf_sql_varchar"  },
                source        = { value = left(trim(arguments.source),        50),  cfsqltype = "cf_sql_varchar"  },
                changedByID   = { value = safeChangedByID, cfsqltype = "cf_sql_integer", null = isNull(safeChangedByID) },
                changedBy     = { value = left(trim(arguments.changedBy),    255),  cfsqltype = "cf_sql_nvarchar" },
                ipAddress     = { value = left(trim(arguments.ipAddress),     50),  cfsqltype = "cf_sql_varchar"  },
                changeSection = { value = left(trim(arguments.changeSection),100),  cfsqltype = "cf_sql_varchar"  },
                description   = { value = left(trim(arguments.description),  500),  cfsqltype = "cf_sql_nvarchar" }
            },
            options = { datasource = variables.dsn }
        );
        return trim(qry.GroupID);
    }

    public void function markGroupReverted(
        required string  groupID,
        required numeric revertedByID,
        required string  revertedBy
    ) {
        executeQueryWithRetry(
            sql = "
                UPDATE dbo.ChangeGroups
                SET RevertedAt = GETUTCDATE(), RevertedByID = :rByID, RevertedBy = :rBy
                WHERE GroupID = :groupID
            ",
            params = {
                groupID = { value = arguments.groupID,   cfsqltype = "cf_sql_varchar"  },
                rByID   = { value = arguments.revertedByID, cfsqltype = "cf_sql_integer" },
                rBy     = { value = left(trim(arguments.revertedBy), 255), cfsqltype = "cf_sql_nvarchar" }
            },
            options = { datasource = variables.dsn }
        );
    }

    // ── Change row management ─────────────────────────────────────────────────

    public void function insertChange(
        required string groupID,
        required string tableName,
        required string pkColumn,
        required string recordID,
        required string action,
        string   beforeJSON = "",
        string   afterJSON  = ""
    ) {
        var safeBeforeJSON = len(trim(arguments.beforeJSON)) ? arguments.beforeJSON : javaCast("null", "");
        var safeAfterJSON  = len(trim(arguments.afterJSON))  ? arguments.afterJSON  : javaCast("null", "");

        executeQueryWithRetry(
            sql = "
                INSERT INTO dbo.ChangeLog
                    (GroupID, TableName, PKColumn, RecordID, Action, BeforeJSON, AfterJSON)
                VALUES
                    (:groupID, :tableName, :pkColumn, :recordID, :action, :beforeJSON, :afterJSON)
            ",
            params = {
                groupID    = { value = arguments.groupID,                            cfsqltype = "cf_sql_varchar"  },
                tableName  = { value = left(trim(arguments.tableName),  100),        cfsqltype = "cf_sql_varchar"  },
                pkColumn   = { value = left(trim(arguments.pkColumn),   100),        cfsqltype = "cf_sql_varchar"  },
                recordID   = { value = left(trim(arguments.recordID),   255),        cfsqltype = "cf_sql_varchar"  },
                action     = { value = left(trim(arguments.action),      10),        cfsqltype = "cf_sql_varchar"  },
                beforeJSON = { value = safeBeforeJSON, cfsqltype = "cf_sql_nvarchar", null = isNull(safeBeforeJSON) },
                afterJSON  = { value = safeAfterJSON,  cfsqltype = "cf_sql_nvarchar", null = isNull(safeAfterJSON)  }
            },
            options = { datasource = variables.dsn }
        );
    }

    // ── Snapshot capture ──────────────────────────────────────────────────────

    /**
     * Fetch all rows from a table where a given column equals a value.
     * Returns an array of structs (column names uppercased), with date values
     * serialized to ISO format so JSON round-trips safely.
     */
    public array function captureTableRows(
        required string tableName,
        required string filterColumn,
        required any    filterValue
    ) {
        // Only allow known safe table names (prevents SQL injection via table name)
        if (!_isAllowedTable(arguments.tableName)) {
            throw(type="Application", message="captureTableRows: table '#arguments.tableName#' is not in the allowed list.");
        }

        var qry = executeQueryWithRetry(
            sql     = "SELECT * FROM dbo.[#arguments.tableName#] WHERE [#arguments.filterColumn#] = :val",
            params  = { val = { value = arguments.filterValue, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn, timeout = 30 }
        );

        return _queryToSafeArray(qry);
    }

    // ── Query methods for the UI ──────────────────────────────────────────────

    public array function getGroupsByEntity(
        required string entityType,
        required string entityID,
        numeric maxRows = 200
    ) {
        var safeMax = max(1, min(val(arguments.maxRows), 1000));
        var qry = executeQueryWithRetry(
            sql = "
                SELECT TOP (#safeMax#)
                    GroupID, EntityType, EntityID, Source,
                    ChangedByID, ChangedBy, ChangeSection, Description,
                    CreatedAt, RevertedAt, RevertedByID, RevertedBy
                FROM dbo.ChangeGroups
                WHERE EntityType = :entityType AND EntityID = :entityID
                ORDER BY CreatedAt DESC
            ",
            params = {
                entityType = { value = arguments.entityType, cfsqltype = "cf_sql_varchar" },
                entityID   = { value = arguments.entityID,   cfsqltype = "cf_sql_varchar" }
            },
            options = { datasource = variables.dsn, timeout = 30 }
        );
        return queryToArray(qry);
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
        var safeMax    = max(1, min(val(arguments.maxRows), 500));
        var safeOffset = max(0, val(arguments.offset));

        var whereClauses = [];
        var params = {};

        if (len(trim(arguments.filterEntityType))) {
            arrayAppend(whereClauses, "EntityType = :entityType");
            params["entityType"] = { value = arguments.filterEntityType, cfsqltype = "cf_sql_varchar" };
        }
        if (len(trim(arguments.filterSource))) {
            arrayAppend(whereClauses, "Source = :source");
            params["source"] = { value = arguments.filterSource, cfsqltype = "cf_sql_varchar" };
        }
        if (len(trim(arguments.filterSection))) {
            arrayAppend(whereClauses, "ChangeSection = :section");
            params["section"] = { value = arguments.filterSection, cfsqltype = "cf_sql_varchar" };
        }
        if (val(arguments.filterAdminID) GT 0) {
            arrayAppend(whereClauses, "ChangedByID = :adminID");
            params["adminID"] = { value = val(arguments.filterAdminID), cfsqltype = "cf_sql_integer" };
        }
        if (len(trim(arguments.dateFrom))) {
            arrayAppend(whereClauses, "CreatedAt >= :dateFrom");
            params["dateFrom"] = { value = arguments.dateFrom, cfsqltype = "cf_sql_timestamp" };
        }
        if (len(trim(arguments.dateTo))) {
            arrayAppend(whereClauses, "CreatedAt <= :dateTo");
            params["dateTo"] = { value = arguments.dateTo, cfsqltype = "cf_sql_timestamp" };
        }

        var whereSQL = arrayLen(whereClauses) ? "WHERE " & arrayToList(whereClauses, " AND ") : "";

        var countQry = executeQueryWithRetry(
            sql     = "SELECT COUNT(*) AS TotalCount FROM dbo.ChangeGroups #whereSQL#",
            params  = params,
            options = { datasource = variables.dsn, timeout = 30 }
        );
        var totalCount = val(countQry.TotalCount);

        var dataQry = executeQueryWithRetry(
            sql = "
                SELECT GroupID, EntityType, EntityID, Source,
                       ChangedByID, ChangedBy, ChangeSection, Description,
                       CreatedAt, RevertedAt, RevertedByID, RevertedBy
                FROM dbo.ChangeGroups
                #whereSQL#
                ORDER BY CreatedAt DESC
                OFFSET #safeOffset# ROWS FETCH NEXT #safeMax# ROWS ONLY
            ",
            params  = params,
            options = { datasource = variables.dsn, timeout = 30 }
        );

        return {
            totalCount = totalCount,
            rows       = queryToArray(dataQry)
        };
    }

    public struct function getGroupByID(required string groupID) {
        var groupQry = executeQueryWithRetry(
            sql = "
                SELECT GroupID, EntityType, EntityID, Source,
                       ChangedByID, ChangedBy, IPAddress, ChangeSection, Description,
                       CreatedAt, RevertedAt, RevertedByID, RevertedBy
                FROM dbo.ChangeGroups
                WHERE GroupID = :groupID
            ",
            params  = { groupID = { value = arguments.groupID, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn, timeout = 30 }
        );

        if (!groupQry.recordCount) {
            return {};
        }

        var changesQry = executeQueryWithRetry(
            sql = "
                SELECT ChangeID, GroupID, TableName, PKColumn, RecordID,
                       Action, BeforeJSON, AfterJSON, CreatedAt
                FROM dbo.ChangeLog
                WHERE GroupID = :groupID
                ORDER BY ChangeID
            ",
            params  = { groupID = { value = arguments.groupID, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn, timeout = 30 }
        );

        var group   = queryToArray(groupQry)[1];
        group.CHANGES = queryToArray(changesQry);
        return group;
    }

    public array function getChangesForGroup(required string groupID) {
        var qry = executeQueryWithRetry(
            sql = "
                SELECT ChangeID, TableName, PKColumn, RecordID, Action, BeforeJSON, AfterJSON
                FROM dbo.ChangeLog
                WHERE GroupID = :groupID
                ORDER BY ChangeID DESC
            ",
            params  = { groupID = { value = arguments.groupID, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn, timeout = 30 }
        );
        return queryToArray(qry);
    }

    // ── Revert operations ─────────────────────────────────────────────────────

    /**
     * Reverts a single-row UPDATE by re-applying all columns from the snapshot struct.
     * snapshot keys must be uppercase column names; values are strings.
     */
    public void function applyUpdateRevert(
        required string tableName,
        required string pkColumn,
        required string pkValue,
        required struct snapshot
    ) {
        if (!_isAllowedTable(arguments.tableName)) {
            throw(type="Application", message="applyUpdateRevert: table '#arguments.tableName#' is not allowed.");
        }

        var setClauses = [];
        var params     = { pk = { value = arguments.pkValue, cfsqltype = "cf_sql_varchar" } };
        var pkUpper    = uCase(arguments.pkColumn);

        for (var colName in arguments.snapshot) {
            if (uCase(colName) EQ pkUpper) continue; // skip PK column itself
            var paramName = "col_" & lCase(reReplace(colName, "[^a-zA-Z0-9]", "_", "all"));
            arrayAppend(setClauses, "[#colName#] = :#paramName#");
            var colVal = arguments.snapshot[colName];
            params[paramName] = _buildParam(colVal);
        }

        if (!arrayLen(setClauses)) return;

        executeQueryWithRetry(
            sql     = "UPDATE dbo.[#arguments.tableName#] SET #arrayToList(setClauses, ', ')# WHERE [#arguments.pkColumn#] = :pk",
            params  = params,
            options = { datasource = variables.dsn, timeout = 30 }
        );
    }

    /**
     * Reverts a REPLACE by deleting all rows for the user then re-inserting from snapshot.
     * autoPKColumn: if set, that column is excluded from the INSERT so the DB generates a new ID.
     */
    public void function applyReplaceRevert(
        required string tableName,
        required string userFKColumn,
        required string userFKValue,
        required array  snapshotRows,
        string          autoPKColumn = ""
    ) {
        if (!_isAllowedTable(arguments.tableName)) {
            throw(type="Application", message="applyReplaceRevert: table '#arguments.tableName#' is not allowed.");
        }

        // Delete all existing rows for this user
        executeQueryWithRetry(
            sql     = "DELETE FROM dbo.[#arguments.tableName#] WHERE [#arguments.userFKColumn#] = :userID",
            params  = { userID = { value = arguments.userFKValue, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn, timeout = 30 }
        );

        // Re-insert each row from the snapshot
        var autoPKUpper = uCase(trim(arguments.autoPKColumn));
        for (var row in arguments.snapshotRows) {
            var colNames   = [];
            var paramNames = [];
            var params     = {};

            for (var colName in row) {
                if (len(autoPKUpper) AND uCase(colName) EQ autoPKUpper) continue; // skip auto PK
                var paramName = "col_" & lCase(reReplace(colName, "[^a-zA-Z0-9]", "_", "all"));
                arrayAppend(colNames,   "[#colName#]");
                arrayAppend(paramNames, ":#paramName#");
                params[paramName] = _buildParam(row[colName]);
            }

            if (!arrayLen(colNames)) continue;

            executeQueryWithRetry(
                sql     = "INSERT INTO dbo.[#arguments.tableName#] (#arrayToList(colNames, ', ')#) VALUES (#arrayToList(paramNames, ', ')#)",
                params  = params,
                options = { datasource = variables.dsn, timeout = 30 }
            );
        }
    }

    /**
     * Re-inserts a single deleted row from a snapshot struct.
     * autoPKColumn: excluded from INSERT if set (let DB generate new identity).
     */
    public void function applyInsertRevert(
        required string tableName,
        required struct snapshot,
        string          autoPKColumn = ""
    ) {
        if (!_isAllowedTable(arguments.tableName)) {
            throw(type="Application", message="applyInsertRevert: table '#arguments.tableName#' is not allowed.");
        }

        var colNames   = [];
        var paramNames = [];
        var params     = {};
        var autoPKUpper = uCase(trim(arguments.autoPKColumn));

        for (var colName in arguments.snapshot) {
            if (len(autoPKUpper) AND uCase(colName) EQ autoPKUpper) continue;
            var paramName = "col_" & lCase(reReplace(colName, "[^a-zA-Z0-9]", "_", "all"));
            arrayAppend(colNames,   "[#colName#]");
            arrayAppend(paramNames, ":#paramName#");
            params[paramName] = _buildParam(arguments.snapshot[colName]);
        }

        if (!arrayLen(colNames)) return;

        executeQueryWithRetry(
            sql     = "INSERT INTO dbo.[#arguments.tableName#] (#arrayToList(colNames, ', ')#) VALUES (#arrayToList(paramNames, ', ')#)",
            params  = params,
            options = { datasource = variables.dsn, timeout = 30 }
        );
    }

    /**
     * Deletes a single row identified by its PK column/value.
     */
    public void function applyDeleteRevert(
        required string tableName,
        required string pkColumn,
        required string pkValue
    ) {
        if (!_isAllowedTable(arguments.tableName)) {
            throw(type="Application", message="applyDeleteRevert: table '#arguments.tableName#' is not allowed.");
        }

        executeQueryWithRetry(
            sql     = "DELETE FROM dbo.[#arguments.tableName#] WHERE [#arguments.pkColumn#] = :pk",
            params  = { pk = { value = arguments.pkValue, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn, timeout = 30 }
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Allowed table whitelist — prevents dynamic SQL injection via table name.
     */
    private boolean function _isAllowedTable(required string tableName) {
        var allowed = {
            "Users"                 : true,
            "UserFlagAssignments"   : true,
            "UserEmails"            : true,
            "UserPhone"             : true,
            "UserAliases"           : true,
            "UserDegrees"           : true,
            "UserAddresses"         : true,
            "UserOrganizations"     : true,
            "UserExternalIDs"       : true,
            "UserBio"               : true,
            "UserAcademicInfo"      : true,
            "UserStudentProfile"    : true,
            "UserAwards"            : true,
            "UserResidency"         : true,
            "UserFlags"             : true,
            "AccessAreas"           : true,
            "AppConfig"             : true
        };
        return structKeyExists(allowed, arguments.tableName);
    }

    /**
     * Converts a query result to an array of structs, with dates serialized as
     * ISO strings so they survive JSON round-trips and can be re-applied via
     * parameterized queries.
     */
    private array function _queryToSafeArray(required any qry) {
        var result  = [];
        if (arguments.qry.recordCount EQ 0) return result;

        var columns = listToArray(arguments.qry.columnList);
        for (var i = 1; i <= arguments.qry.recordCount; i++) {
            var row = {};
            for (var col in columns) {
                var val = arguments.qry[col][i];
                if (isNull(val)) {
                    row[uCase(col)] = "";
                } else if (isDate(val) AND NOT isNumeric(val)) {
                    // Serialize dates as ISO strings so JSON round-trips safely
                    row[uCase(col)] = dateTimeFormat(val, "yyyy-mm-dd'T'HH:nn:ss");
                } else {
                    row[uCase(col)] = toString(val);
                }
            }
            arrayAppend(result, row);
        }
        return result;
    }

    /**
     * Builds a cf_sql_nvarchar param struct from a value, handling nulls.
     * SQL Server handles implicit conversions from nvarchar to INT, BIT, DATE etc.
     */
    private struct function _buildParam(required any val) {
        if (isNull(arguments.val) OR (isSimpleValue(arguments.val) AND !len(trim(toString(arguments.val))))) {
            return { value = "", cfsqltype = "cf_sql_nvarchar", null = true };
        }
        return { value = toString(arguments.val), cfsqltype = "cf_sql_nvarchar" };
    }

}
