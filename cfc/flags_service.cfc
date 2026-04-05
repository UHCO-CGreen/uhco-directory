component output="false" singleton {

    public any function init() {
        variables.FlagsDAO = createObject("component", "dir.dao.flags_DAO").init();
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

    public struct function createFlag( required string flagName ) {
        var name = trim(flagName);
        
        if (!len(name)) {
            return { success=false, message="Flag name is required." };
        }
        
        var newID = variables.FlagsDAO.createFlag(name);
        
        return { 
            success=true, 
            message="Flag created.", 
            flagID=newID 
        };
    }

    public struct function updateFlag( required numeric flagID, required string flagName ) {
        var name = trim(flagName);
        
        if (!len(name)) {
            return { success=false, message="Flag name is required." };
        }
        
        variables.FlagsDAO.updateFlag(flagID, name);
        
        return { success=true, message="Flag updated." };
    }

    public struct function deleteFlag( required numeric flagID ) {
        variables.FlagsDAO.removeAllAssignmentsForFlag(flagID);
        variables.FlagsDAO.deleteFlag(flagID);
        return { success=true, message="Flag deleted." };
    }

}
