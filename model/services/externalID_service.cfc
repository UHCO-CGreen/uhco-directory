component output="false" singleton {

    public any function init() {
        variables.ExternalIDsDAO = createObject("component", "dao.externalIDs_DAO").init();
        variables.ExternalSystemsDAO = createObject("component", "dao.externalsystems_DAO").init();
        return this;
    }

    public struct function getSystems() {
        return {
            success=true,
            data=variables.ExternalSystemsDAO.getSystems()
        };
    }

    public struct function getSystem( required numeric systemID ) {
        var rows = variables.ExternalSystemsDAO.getSystem( arguments.systemID );
        if ( arrayLen(rows) ) {
            return { success=true, data=rows[1] };
        }
        return { success=false, message="System not found." };
    }

    public struct function updateSystem( required numeric systemID, required string systemName ) {
        variables.ExternalSystemsDAO.updateSystem( arguments.systemID, arguments.systemName );
        return { success=true, message="System updated." };
    }

    public struct function deleteSystem( required numeric systemID ) {
        variables.ExternalSystemsDAO.deleteSystem( arguments.systemID );
        return { success=true, message="System deleted." };
    }

    public struct function getExternalIDs( required numeric userID ) {
        return { success=true, data=variables.ExternalIDsDAO.getExternalIDs( userID ) };
    }

    public struct function setExternalID(
        required numeric userID,
        required numeric systemID,
        required string value
    ) {
        variables.ExternalIDsDAO.setExternalID( userID, systemID, trim( value ) );
        return { success=true, message="External ID saved." };
    }

    public struct function deleteExternalID(
        required numeric userID,
        required numeric systemID
    ) {
        variables.ExternalIDsDAO.deleteExternalID(arguments.userID, arguments.systemID);
        return { success=true, message="External ID removed." };
    }

    // Returns struct keyed by UserID → { lowerSystemName: externalValue, ... }
    public struct function getAllUserExternalIDsMap() {
        var allRows = variables.ExternalIDsDAO.getAllExternalIDs();
        var allSystems = variables.ExternalSystemsDAO.getSystems();
        var systemNames = {};
        for ( var sys in allSystems ) {
            systemNames[toString(sys.SYSTEMID)] = lCase(trim(sys.SYSTEMNAME ?: ""));
        }
        var result = {};
        for ( var row in allRows ) {
            var key = toString(row.USERID);
            if ( !structKeyExists(result, key) ) result[key] = {};
            var sysName = structKeyExists(systemNames, toString(row.SYSTEMID)) ? systemNames[toString(row.SYSTEMID)] : "";
            if ( len(sysName) ) result[key][sysName] = trim(row.EXTERNALVALUE ?: "");
        }
        return result;
    }

    // Returns struct keyed by ExternalValue (trimmed, lower-cased) → UserID, for a given SystemID
    public struct function getValueToUserMap( required numeric systemID ) {
        var rows = variables.ExternalIDsDAO.getAllExternalIDs();
        var result = {};
        for ( var row in rows ) {
            if ( row.SYSTEMID == arguments.systemID ) {
                var k = lCase( trim( row.EXTERNALVALUE ) );
                if ( len(k) ) result[ k ] = row.USERID;
            }
        }
        return result;
    }

}