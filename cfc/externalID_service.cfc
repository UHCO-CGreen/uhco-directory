component output="false" singleton {

    public any function init() {
        variables.ExternalIDsDAO = createObject("component", "dir.dao.externalIDs_DAO").init();
        variables.ExternalSystemsDAO = createObject("component", "dir.dao.externalsystems_DAO").init();
        return this;
    }

    public struct function getSystems() {
        return {
            success=true,
            data=variables.ExternalSystemsDAO.getSystems()
        };
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