component output="false" singleton {

    public any function init() {
        variables.FlagsDAO = createObject("component", "dao.flags_DAO").init();
        return this;
    }

    public struct function getAllFlags() {
        return {
            success=true,
            data=variables.FlagsDAO.getAllFlags()
        };
    }

    public struct function getUserFlags( required numeric userID ) {
        return {
            success=true,
            data=variables.FlagsDAO.getFlagsForUser( userID )
        };
    }

    public struct function getAllUserFlagMap() {
        var rows = variables.FlagsDAO.getAllUserFlagAssignments();
        var result = {};
        for ( var row in rows ) {
            var key = toString( row.USERID );
            if ( !structKeyExists( result, key ) ) result[ key ] = [];
            arrayAppend( result[ key ], { FLAGID=row.FLAGID, FLAGNAME=row.FLAGNAME } );
        }
        return result;
    }

    /**
     * Add a flag with validation
     */
    public struct function addFlag( required numeric userID, required numeric flagID ) {

        // Prevent duplicates (business rule)
        var existing = variables.FlagsDAO.getFlagsForUser( userID );
        for ( f in existing ) {
            if ( f.FlagID == flagID ) {
                return {
                    success=false,
                    message="User already has this flag."
                };
            }
        }

        variables.FlagsDAO.assignFlag( userID, flagID );

        return { success=true, message="Flag assigned." };
    }

    public struct function removeFlag( required numeric userID, required numeric flagID ) {
        variables.FlagsDAO.removeFlag( userID, flagID );
        return { success=true, message="Flag removed." };
    }

    public struct function createFlag( required string flagName, string flagDescription="" ) {
        var name = trim(flagName);
        var description = trim(flagDescription);

        if (!len(name)) {
            return { success=false, message="Flag name is required." };
        }

        var newID = variables.FlagsDAO.createFlag(name, description);

        try {
            if (structKeyExists(application, "changeLogSvc") AND isObject(application.changeLogSvc)) {
                var clGroupID = application.changeLogSvc.beginGroup("flag_def", toString(newID), "Flag Definitions", "Created flag: #name#");
                application.changeLogSvc.logDirectChange(
                    groupID    = clGroupID,
                    tableName  = "UserFlags",
                    pkColumn   = "FlagID",
                    recordID   = toString(newID),
                    action     = "INSERT",
                    afterData  = { FLAGID=newID, FLAGNAME=name, FLAGDESCRIPTION=description }
                );
            }
        } catch (any ignore) {}

        return {
            success=true,
            message="Flag created.",
            flagID=newID
        };
    }

    public struct function updateFlag( required numeric flagID, required string flagName, string flagDescription="" ) {
        var name = trim(flagName);
        var description = trim(flagDescription);

        if (!len(name)) {
            return { success=false, message="Flag name is required." };
        }

        var beforeRows = [];
        var clGroupID  = "";
        try {
            if (structKeyExists(application, "changeLogSvc") AND isObject(application.changeLogSvc)) {
                clGroupID  = application.changeLogSvc.beginGroup("flag_def", toString(arguments.flagID), "Flag Definitions", "Updated flag #arguments.flagID#");
                beforeRows = variables.FlagsDAO.getFlagByID(arguments.flagID);
                beforeRows = isArray(beforeRows) ? beforeRows : (structCount(beforeRows) ? [beforeRows] : []);
            }
        } catch (any ignore) {}

        variables.FlagsDAO.updateFlag(flagID, name, description);

        try {
            if (len(clGroupID)) {
                application.changeLogSvc.logDirectChange(
                    groupID    = clGroupID,
                    tableName  = "UserFlags",
                    pkColumn   = "FlagID",
                    recordID   = toString(arguments.flagID),
                    action     = "UPDATE",
                    beforeData = arrayLen(beforeRows) ? beforeRows[1] : {},
                    afterData  = { FLAGID=arguments.flagID, FLAGNAME=name, FLAGDESCRIPTION=description }
                );
            }
        } catch (any ignore) {}

        return { success=true, message="Flag updated." };
    }

    public struct function deleteFlag( required numeric flagID ) {
        var beforeRows = [];
        var clGroupID  = "";
        try {
            if (structKeyExists(application, "changeLogSvc") AND isObject(application.changeLogSvc)) {
                clGroupID  = application.changeLogSvc.beginGroup("flag_def", toString(arguments.flagID), "Flag Definitions", "Deleted flag #arguments.flagID#");
                beforeRows = variables.FlagsDAO.getFlagByID(arguments.flagID);
                beforeRows = isArray(beforeRows) ? beforeRows : (structCount(beforeRows) ? [beforeRows] : []);
            }
        } catch (any ignore) {}

        variables.FlagsDAO.removeAllAssignmentsForFlag(flagID);
        variables.FlagsDAO.deleteFlag(flagID);

        try {
            if (len(clGroupID)) {
                application.changeLogSvc.logDirectChange(
                    groupID    = clGroupID,
                    tableName  = "UserFlags",
                    pkColumn   = "FlagID",
                    recordID   = toString(arguments.flagID),
                    action     = "DELETE",
                    beforeData = arrayLen(beforeRows) ? beforeRows[1] : {}
                );
            }
        } catch (any ignore) {}

        return { success=true, message="Flag deleted." };
    }

}
