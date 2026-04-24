component output="false" singleton {

    public any function init() {
        return this;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPERS — Memorial Day & grad-year logic (delegates to helpers.cfc)
    // ══════════════════════════════════════════════════════════════════════════

    /** Memorial Day date for a given year. */
    public date function getMemorialDayDate( required numeric year ) {
        return helpersSvc().getMemorialDayDate( arguments.year );
    }

    /** Full grad-year window struct { memorialDay, startYear, endYear, graduatingYear }. */
    public struct function getGradYearWindow() {
        return helpersSvc().getGradYearWindow();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CONFIG
    // ══════════════════════════════════════════════════════════════════════════

    public boolean function isAutoExecuteEnabled() {
        return migrationDAO().getAutoExecuteEnabled();
    }

    public void function setAutoExecute( required boolean enabled ) {
        migrationDAO().setAutoExecuteEnabled( arguments.enabled );
    }

    public string function getNotifyEmail() {
        return migrationDAO().getNotifyEmail();
    }

    public void function setNotifyEmail( required string email ) {
        migrationDAO().setNotifyEmail( arguments.email );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // RUN QUERIES
    // ══════════════════════════════════════════════════════════════════════════

    public struct function getLatestRun() {
        return migrationDAO().getLatestRun();
    }

    public array function getRecentRuns( numeric maxRuns=10 ) {
        return migrationDAO().getRecentRuns( arguments.maxRuns );
    }

    public struct function getRunByID( required numeric runID ) {
        return migrationDAO().getRunByID( arguments.runID );
    }

    public array function getDetailsByRun( required numeric runID ) {
        return migrationDAO().getDetailsByRun( arguments.runID );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PREVIEW — read-only, no side effects
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Preview which students would be migrated for a given grad year.
     * Returns { success, gradYear, memorialDay, totalStudents, students[] }.
     */
    public struct function preview( required numeric gradYear ) {
        var students   = migrationDAO().getGraduatingStudents( arguments.gradYear );
        var memDay     = getMemorialDayDate( year(now()) );
        var flagLookup = resolveFlagIDs();

        return {
            success       = true,
            gradYear      = arguments.gradYear,
            memorialDay   = memDay,
            totalStudents = arrayLen(students),
            students      = students,
            alumniFlagID  = flagLookup.alumniFlagID,
            studentFlagID = flagLookup.studentFlagID
        };
    }

    // ══════════════════════════════════════════════════════════════════════════
    // EXECUTE — full migration
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Execute the graduation migration for a given grad year.
     * @gradYear     The graduating class year to migrate
     * @triggeredBy  Username or "scheduled"
     * @returns      Struct with run summary
     */
    public struct function execute( required numeric gradYear, required string triggeredBy ) {
        var mode = ( arguments.triggeredBy == "scheduled" ) ? "scheduled" : "manual";
        var runID = 0;
        var dao = migrationDAO();
        var flagsSvc = flagsService();
        var userSvc = usersService();

        try {
            // Duplicate guard: skip if a completed run already exists for this year
            var existing = dao.getCompletedRunForYear( arguments.gradYear );
            if ( !structIsEmpty(existing) ) {
                return {
                    success = false,
                    message = "A completed migration already exists for #arguments.gradYear# (Run ###existing.RUNID#). Rollback that run first or choose a different year."
                };
            }

            // Resolve flag IDs
            var flagLookup = resolveFlagIDs();
            if ( !flagLookup.success ) {
                return { success=false, message=flagLookup.message };
            }

            // Get target students
            var students = dao.getGraduatingStudents( arguments.gradYear );
            if ( arrayLen(students) == 0 ) {
                return {
                    success = false,
                    message = "No active current-student users found with grad year #arguments.gradYear#."
                };
            }

            // Create run record
            runID = dao.createRun( arguments.gradYear, mode, arguments.triggeredBy );

            var totalMigrated = 0;
            var totalErrors   = 0;

            // Process each student
            for ( var student in students ) {
                var detailID = 0;
                try {
                    transaction {
                        // Insert detail as pending
                        detailID = dao.insertDetail(
                            runID,
                            student.USERID,
                            flagLookup.studentFlagID,
                            flagLookup.alumniFlagID,
                            student.TITLE1,
                            "Alumni"
                        );

                        // Step 1: Remove current-student flag
                        flagsSvc.removeFlag( student.USERID, flagLookup.studentFlagID );

                        // Step 2: Add alumni flag
                        flagsSvc.addFlag( student.USERID, flagLookup.alumniFlagID );

                        // Step 3: Update Title1 to "Alumni"
                        userSvc.updateTitle1Field( student.USERID, "Alumni" );

                        // Step 4: Remove student-specific exclusions
                        var removedCount = dao.removeStudentExclusions( student.USERID );

                        // Step 5: Add alumni exclusions
                        var addedCount = dao.addAlumniExclusions( student.USERID );

                        // Mark success
                        dao.updateDetailStatus(
                            detailID, "migrated", addedCount, removedCount
                        );
                    }
                    totalMigrated++;

                } catch ( any e ) {
                    totalErrors++;
                    if ( detailID > 0 ) {
                        var errText = trim(e.message ?: "Unknown error");
                        if ( len(trim(e.detail ?: "")) ) {
                            errText &= " — " & trim(e.detail);
                        }
                        dao.updateDetailStatus(
                            detailID, "error", 0, 0, left(errText, 500)
                        );
                    }
                }
            }

            // Finalize run
            var finalStatus = "failed";
            if ( totalMigrated == arrayLen(students) ) {
                finalStatus = "completed";
            } else if ( totalMigrated > 0 ) {
                finalStatus = "completed_w_errors";
            }
            dao.updateRunTotals( runID, arrayLen(students), totalMigrated, totalErrors );
            dao.updateRunStatus( runID, finalStatus );

            // Send notification
            try {
                sendNotification( runID );
            } catch ( any e ) {
                // Notification failure should not fail the migration
            }

            return {
                success       = (finalStatus == "completed" || finalStatus == "completed_w_errors"),
                runID         = runID,
                status        = finalStatus,
                gradYear      = arguments.gradYear,
                totalTargeted = arrayLen(students),
                totalMigrated = totalMigrated,
                totalErrors   = totalErrors,
                message       = (finalStatus == "completed_w_errors")
                    ? "Migration finished with errors. Some users were not migrated."
                    : ""
            };

        } catch ( any e ) {
            // If run was created, mark it failed
            if ( runID > 0 ) {
                try {
                    dao.updateRunStatus( runID, "failed" );
                } catch ( any e2 ) { /* swallow */ }
            }
            return {
                success = false,
                message = "Migration failed: " & e.message,
                runID   = runID
            };
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // ROLLBACK
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Rollback a completed/partial migration run.
     * @runID         The run to roll back
     * @rolledBackBy  Username performing the rollback
     */
    public struct function rollback( required numeric runID, required string rolledBackBy ) {
        var dao = migrationDAO();
        var flagsSvc = flagsService();
        var userSvc = usersService();
        var run = dao.getRunByID( arguments.runID );
        if ( structIsEmpty(run) ) {
            return { success=false, message="Run not found." };
        }
        if ( !listFindNoCase("completed,completed_w_errors,failed", run.STATUS) ) {
            return { success=false, message="Only completed, completed_w_errors, or failed runs can be rolled back. Current status: #run.STATUS#" };
        }

        var flagLookup = resolveFlagIDs();
        if ( !flagLookup.success ) {
            return { success=false, message=flagLookup.message };
        }

        var details = dao.getDetailsByRun( arguments.runID );
        var migratedDetails = [];
        for ( var d in details ) {
            if ( listFindNoCase("migrated,error", d.STATUS) ) arrayAppend( migratedDetails, d );
        }

        if ( arrayLen(migratedDetails) == 0 ) {
            return {
                success = false,
                message = "Run ###arguments.runID# has no migrated/error user records to roll back."
            };
        }

        // Transactional rollback: either all user reversals succeed or none are persisted.
        try {
            transaction {
                for ( var detail in migratedDetails ) {
                    // Reverse flag: remove alumni, re-add current-student
                    flagsSvc.removeFlag( detail.USERID, flagLookup.alumniFlagID );
                    flagsSvc.addFlag( detail.USERID, flagLookup.studentFlagID );

                    // Restore Title1
                    userSvc.updateTitle1Field( detail.USERID, detail.PREVIOUSTITLE1 );

                    // Exclusion-set reset is best-effort; if this fails, do not block core rollback.
                    try {
                        dao.removeAlumniExclusions( detail.USERID );
                        dao.addStudentExclusions( detail.USERID );
                    } catch ( any exclusionErr ) {
                        // Keep rollback moving for this user; details capture this user's prior error row already.
                    }
                }

                // Mark run and details as rolled back only after all user-level reversals succeed.
                dao.markDetailsRolledBack( arguments.runID );
                dao.markRunRolledBack( arguments.runID, arguments.rolledBackBy );
            }

            return {
                success         = true,
                runID           = arguments.runID,
                totalRolledBack = arrayLen(migratedDetails),
                totalErrors     = 0
            };
        } catch ( any e ) {
            var rbErrText = trim(e.message ?: "Unknown rollback error");
            if ( len(trim(e.detail ?: "")) ) {
                rbErrText &= " — " & trim(e.detail);
            }
            return {
                success     = false,
                runID       = arguments.runID,
                message     = "Rollback failed and was not committed: " & rbErrText,
                totalErrors = 1
            };
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // NOTIFICATION
    // ══════════════════════════════════════════════════════════════════════════

    /** Send email notification for a completed run. */
    public void function sendNotification( required numeric runID ) {
        var notifyEmail = getNotifyEmail();
        var dao = migrationDAO();
        if ( !len(notifyEmail) || !isValid("email", notifyEmail) ) return;

        var run = dao.getRunByID( arguments.runID );
        if ( structIsEmpty(run) ) return;

        var subject = "UHCO Graduation Migration — Class of #run.GRADYEAR# — #uCase(run.STATUS)#";
        var body = "
            Graduation Migration Run ###run.RUNID#

            Grad Year:     #run.GRADYEAR#
            Status:        #run.STATUS#
            Mode:          #run.MODE#
            Triggered By:  #run.TRIGGEREDBY#
            Executed At:   #dateTimeFormat(run.EXECUTEDAT, 'MM/dd/yyyy hh:nn tt')#

            Total Targeted: #run.TOTALTARGETED#
            Total Migrated: #run.TOTALMIGRATED#
            Total Errors:   #run.TOTALERRORS#

            View details at: /admin/reporting/grad_migration_detail.cfm?runID=#run.RUNID#
        ";

        cfmail(
            to      = notifyEmail,
            from    = "noreply@uh.edu",
            subject = subject,
            type    = "text"
        ) {
            writeOutput( trim(body) );
        }

        dao.markNotificationSent( arguments.runID );
    }

    // ══════════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Look up the FlagIDs for "current-student" and "alumni".
     * Returns { success, studentFlagID, alumniFlagID, message }.
     */
    private struct function resolveFlagIDs() {
        var flagResult = flagsService().getAllFlags();
        var studentFlagID = 0;
        var alumniFlagID  = 0;

        for ( var f in flagResult.data ) {
            if ( lCase(trim(f.FLAGNAME)) == "current-student" ) studentFlagID = f.FLAGID;
            if ( lCase(trim(f.FLAGNAME)) == "alumni" )          alumniFlagID  = f.FLAGID;
        }

        if ( studentFlagID == 0 || alumniFlagID == 0 ) {
            return {
                success       = false,
                studentFlagID = studentFlagID,
                alumniFlagID  = alumniFlagID,
                message       = "Could not find required flags. current-student=#studentFlagID#, alumni=#alumniFlagID#"
            };
        }

        return {
            success       = true,
            studentFlagID = studentFlagID,
            alumniFlagID  = alumniFlagID,
            message       = ""
        };
    }

    private any function migrationDAO() {
        return createObject("component", "dao.gradMigration_DAO").init();
    }

    private any function flagsService() {
        return createObject("component", "cfc.flags_service").init();
    }

    private any function usersService() {
        return createObject("component", "cfc.users_service").init();
    }

    private any function helpersSvc() {
        return createObject("component", "cfc.helpers").init();
    }

}
