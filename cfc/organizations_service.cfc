component output="false" singleton {

    public any function init() {
        variables.OrganizationsDAO = createObject("component", "dir.dao.organizations_DAO").init();
        return this;
    }

    public struct function getAllOrgs() {
        return {
            success=true,
            data=variables.OrganizationsDAO.getAllOrgs()
        };
    }

    /**
     * Business rule example:
     * A faculty member MUST have at least one organization assignment.
     */
    public struct function validateFacultyOrgRequirement( required numeric userID ) {
        var orgs = variables.OrganizationsDAO.getOrgAssignments( userID );
        return ( arrayLen( orgs ) > 0 );
    }

    public struct function assignOrg( required numeric userID, required numeric orgID, string roleTitle="", numeric roleOrder=0 ) {
        variables.OrganizationsDAO.assignOrg( userID, orgID, arguments.roleTitle, arguments.roleOrder );
        return { success=true, message="Organization assigned." };
    }

    public struct function updateOrgAssignment( required numeric userID, required numeric orgID, string roleTitle="", numeric roleOrder=0 ) {
        variables.OrganizationsDAO.updateOrgAssignment( userID, orgID, arguments.roleTitle, arguments.roleOrder );
        return { success=true, message="Organization assignment updated." };
    }

    public struct function removeOrg( required numeric userID, required numeric orgID ) {
        variables.OrganizationsDAO.removeOrg( userID, orgID );
        return { success=true, message="Organization removed." };
    }

    public struct function getUserOrgs( required numeric userID ) {
        return {
            success=true,
            data=variables.OrganizationsDAO.getOrgAssignments( userID )
        };
    }

    public struct function getAllUserOrgMap() {
        var rows = variables.OrganizationsDAO.getAllUserOrgAssignments();
        var result = {};
        for ( var row in rows ) {
            var key = toString( row.USERID );
            if ( !structKeyExists( result, key ) ) result[ key ] = [];
            arrayAppend( result[ key ], { ORGID=row.ORGID, ORGNAME=row.ORGNAME, ORGTYPE=row.ORGTYPE, PARENTORGID=row.PARENTORGID } );
        }
        return result;
    }

    public struct function getOrg( required numeric orgID ) {
        var org = variables.OrganizationsDAO.getOrgByID( orgID );
        if ( structIsEmpty( org ) ) {
            return { success=false, message="Organization not found.", data={} };
        }
        return { success=true, data=org };
    }

    public struct function createOrg( required string orgName, string orgType="", any parentOrgID="", numeric additionalRoles=0 ) {
        var newID = variables.OrganizationsDAO.createOrg( orgName, orgType, parentOrgID, arguments.additionalRoles );
        return { success=true, message="Organization created.", orgID=newID };
    }

    public struct function updateOrg( required numeric orgID, required string orgName, string orgType="", any parentOrgID="", numeric additionalRoles=0 ) {
        variables.OrganizationsDAO.updateOrg( orgID, orgName, orgType, parentOrgID, arguments.additionalRoles );
        return { success=true, message="Organization updated." };
    }

    public struct function deleteOrg( required numeric orgID ) {
        variables.OrganizationsDAO.removeAllUserAssignmentsForOrg( orgID );
        variables.OrganizationsDAO.clearChildOrgParents( orgID );
        variables.OrganizationsDAO.deleteOrg( orgID );
        return { success=true, message="Organization deleted." };
    }

}