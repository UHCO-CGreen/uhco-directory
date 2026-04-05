component output="false" singleton {

    public any function init() {
        variables.AccessDAO = createObject("component", "dir.dao.access_DAO").init();
        return this;
    }

    public struct function getAccessAreas() {
        return {
            success=true,
            data=variables.AccessDAO.getAccessAreas()
        };
    }

    public struct function getAccessForUser( required numeric userID ) {
        return { success=true, data=variables.AccessDAO.getAccessForUser( userID ) };
    }

    public struct function grantAccess( required numeric userID, required numeric areaID ) {
        variables.AccessDAO.grantAccess( userID, areaID );
        return { success=true, message="Access granted." };
    }

    public struct function revokeAccess( required numeric userID, required numeric areaID ) {
        variables.AccessDAO.revokeAccess( userID, areaID );
        return { success=true, message="Access revoked." };
    }

}