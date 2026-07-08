component output="false" singleton {

    /**
     * changeLog_revert_service — Applies database rollbacks from ChangeLog rows.
     *
     * Called exclusively by changeLog_service.revertGroup(). Not intended for
     * direct use from admin CFMs.
     *
     * Per-table metadata tells the revert engine which column is the auto-
     * generated identity PK (skipped on re-INSERT) and which column holds the
     * user FK (used for WHERE clauses in REPLACE reversals).
     */

    public any function init() {

        // autoPK: the IDENTITY column name (uppercase). Empty = no identity PK.
        // userFK: the user foreign-key column used for WHERE [userFK] = userID.
        variables.tableMeta = {
            "USERS"                  : { autoPK : "",            userFK : "USERID"    },
            "USERFLAGASSIGNMENTS"    : { autoPK : "",            userFK : "USERID"    },
            "USEREMAILS"             : { autoPK : "EMAILID",     userFK : "USERID"    },
            "USERPHONE"              : { autoPK : "PHONEID",     userFK : "USERID"    },
            "USERALIASES"            : { autoPK : "ALIASID",     userFK : "USERID"    },
            "USERDEGREES"            : { autoPK : "DEGREEID",    userFK : "USERID"    },
            "USERADDRESSES"          : { autoPK : "ADDRESSID",   userFK : "USERID"    },
            "USERORGANIZATIONS"      : { autoPK : "",            userFK : "USERID"    },
            "USEREXTERNALIDS"        : { autoPK : "",            userFK : "USERID"    },
            "USERBIO"                : { autoPK : "BIOID",       userFK : "USERID"    },
            "USERACADEMICINFO"       : { autoPK : "ACADEMICID",  userFK : "USERID"    },
            "USERSTUDENTPROFILE"     : { autoPK : "PROFILEID",   userFK : "USERID"    },
            "USERAWARDS"             : { autoPK : "AWARDID",     userFK : "USERID"    },
            "USERRESIDENCY"          : { autoPK : "RESIDENCYID", userFK : "USERID"    },
            "USERFLAGS"              : { autoPK : "FLAGID",      userFK : ""          },
            "ACCESSAREAS"            : { autoPK : "ACCESSAREAID",userFK : ""          },
            "APPCONFIG"              : { autoPK : "",            userFK : ""          }
        };

        return this;
    }

    /**
     * Reverts all ChangeLog rows for the given group in reverse insertion order.
     * Executes everything inside a single transaction.
     * Marks the group as reverted on success.
     *
     * @changeLogDAO  The changeLog_DAO singleton (passed in to avoid circular deps)
     * @group         The full group struct returned by changeLog_DAO.getGroupByID()
     * @revertedByID  AdminUsers.user_id of the reverting admin
     * @revertedBy    Display name of the reverting admin
     */
    public void function revertGroup(
        required any    changeLogDAO,
        required struct group,
        required numeric revertedByID,
        required string  revertedBy
    ) {
        var groupID = trim(arguments.group.GROUPID ?: "");
        var changes = arguments.group.CHANGES ?: [];

        // Reverse insertion order so dependent rows are undone correctly
        var reversedChanges = [];
        for (var i = arrayLen(changes); i >= 1; i--) {
            arrayAppend(reversedChanges, changes[i]);
        }

        transaction {
            try {
                for (var change in reversedChanges) {
                    _applyOneRevert(arguments.changeLogDAO, change);
                }
                arguments.changeLogDAO.markGroupReverted(
                    groupID     = groupID,
                    revertedByID= arguments.revertedByID,
                    revertedBy  = arguments.revertedBy
                );
            } catch (any err) {
                transaction action="rollback";
                rethrow;
            }
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private void function _applyOneRevert(required any changeLogDAO, required struct change) {
        var action    = uCase(trim(change.ACTION ?: ""));
        var tableName = trim(change.TABLENAME ?: "");
        var pkColumn  = trim(change.PKCOLUMN ?: "");
        var recordID  = trim(change.RECORDID ?: "");

        var meta      = _getTableMeta(tableName);
        var autoPK    = meta.autoPK;
        var userFK    = meta.userFK;

        switch (action) {
            case "UPDATE":
                // Re-apply the before-state as an UPDATE
                if (!len(change.BEFOREJSON ?: "")) return;
                var beforeStruct = deserializeJSON(change.BEFOREJSON);
                arguments.changeLogDAO.applyUpdateRevert(
                    tableName = tableName,
                    pkColumn  = pkColumn,
                    pkValue   = recordID,
                    snapshot  = beforeStruct
                );
                break;

            case "INSERT":
                // The original action was an INSERT; revert = DELETE the row
                arguments.changeLogDAO.applyDeleteRevert(
                    tableName = tableName,
                    pkColumn  = pkColumn,
                    pkValue   = recordID
                );
                break;

            case "DELETE":
                // The original action was a DELETE; revert = re-INSERT the row
                if (!len(change.BEFOREJSON ?: "")) return;
                var delBeforeStruct = deserializeJSON(change.BEFOREJSON);
                arguments.changeLogDAO.applyInsertRevert(
                    tableName    = tableName,
                    snapshot     = delBeforeStruct,
                    autoPKColumn = autoPK
                );
                break;

            case "REPLACE":
                // Full set replacement: delete all rows for userID, re-insert from before array
                if (!len(change.BEFOREJSON ?: "")) {
                    // Before was empty — just delete all current rows
                    if (len(userFK)) {
                        arguments.changeLogDAO.applyReplaceRevert(
                            tableName     = tableName,
                            userFKColumn  = userFK,
                            userFKValue   = recordID,
                            snapshotRows  = [],
                            autoPKColumn  = autoPK
                        );
                    }
                    return;
                }
                var replaceBeforeRows = deserializeJSON(change.BEFOREJSON);
                if (!isArray(replaceBeforeRows)) {
                    // Tolerate a single-struct before (shouldn't happen for REPLACE but guard)
                    replaceBeforeRows = isStruct(replaceBeforeRows) ? [replaceBeforeRows] : [];
                }
                if (len(userFK)) {
                    arguments.changeLogDAO.applyReplaceRevert(
                        tableName    = tableName,
                        userFKColumn = userFK,
                        userFKValue  = recordID,
                        snapshotRows = replaceBeforeRows,
                        autoPKColumn = autoPK
                    );
                }
                break;
        }
    }

    private struct function _getTableMeta(required string tableName) {
        var key = uCase(trim(arguments.tableName));
        return structKeyExists(variables.tableMeta, key)
            ? variables.tableMeta[key]
            : { autoPK: "", userFK: "USERID" };
    }

}
