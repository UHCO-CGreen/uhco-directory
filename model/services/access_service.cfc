component output="false" singleton {

    public any function init() {
        variables.AccessDAO = createObject("component", "dao.access_DAO").init();
        return this;
    }

    public struct function getAccessAreas() {
        return {
            success=true,
            data=variables.AccessDAO.getAccessAreas()
        };
    }

    public struct function getAccessAreaByID(required numeric areaID) {
        var area = variables.AccessDAO.getAccessAreaByID(arguments.areaID);
        return {
            success = !structIsEmpty(area),
            data = area,
            message = structIsEmpty(area) ? "Access area not found." : ""
        };
    }

    public struct function createAccessArea(required string accessName) {
        var normalizedName = trim(arguments.accessName);
        var areaID = 0;

        if (!len(normalizedName)) {
            return { success=false, message="Access name is required." };
        }

        areaID = variables.AccessDAO.createAccessArea(normalizedName);

        return {
            success = areaID GT 0,
            areaID = areaID,
            message = areaID GT 0 ? "Access area created." : "Unable to create access area."
        };
    }

    public struct function updateAccessArea(required numeric areaID, required string accessName) {
        var normalizedName = trim(arguments.accessName);
        var existingArea = {};

        if (arguments.areaID LTE 0) {
            return { success=false, message="Invalid access area." };
        }

        if (!len(normalizedName)) {
            return { success=false, message="Access name is required." };
        }

        existingArea = variables.AccessDAO.getAccessAreaByID(arguments.areaID);
        if (structIsEmpty(existingArea)) {
            return { success=false, message="Access area not found." };
        }

        variables.AccessDAO.updateAccessArea(arguments.areaID, normalizedName);
        return { success=true, message="Access area updated." };
    }

    public struct function deleteAccessArea(required numeric areaID) {
        var existingArea = {};
        var assignmentCount = 0;

        if (arguments.areaID LTE 0) {
            return { success=false, message="Invalid access area." };
        }

        existingArea = variables.AccessDAO.getAccessAreaByID(arguments.areaID);
        if (structIsEmpty(existingArea)) {
            return { success=false, message="Access area not found." };
        }

        assignmentCount = variables.AccessDAO.countAssignmentsForArea(arguments.areaID);
        if (assignmentCount GT 0) {
            return {
                success = false,
                message = "Access area cannot be deleted while it is assigned to users."
            };
        }

        variables.AccessDAO.deleteAccessArea(arguments.areaID);
        return { success=true, message="Access area deleted." };
    }

    public numeric function countAssignmentsForArea(required numeric areaID) {
        return variables.AccessDAO.countAssignmentsForArea(arguments.areaID);
    }

    public struct function getAccessForUser( required numeric userID ) {
        return { success=true, data=variables.AccessDAO.getAccessForUser( userID ) };
    }

    public struct function getPermissionsForUser( required numeric userID ) {
        var rows = variables.AccessDAO.getPermissionsForUser( userID );
        var perms = [];
        for ( var row in rows ) {
            arrayAppend( perms, row.ACCESSNAME );
        }
        return { success=true, data=perms };
    }

    public struct function grantAccess(
        required numeric userID,
        required numeric areaID,
        numeric grantedBy = 0
    ) {
        variables.AccessDAO.grantAccess( userID, areaID, grantedBy );
        return { success=true, message="Access granted." };
    }

    public struct function revokeAccess( required numeric userID, required numeric areaID ) {
        variables.AccessDAO.revokeAccess( userID, areaID );
        return { success=true, message="Access revoked." };
    }

    public struct function getUsersForPermission( required string permission ) {
        return { success=true, data=variables.AccessDAO.getUsersForPermission( trim(arguments.permission) ) };
    }

}