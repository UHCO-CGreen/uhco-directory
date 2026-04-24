component output="false" singleton {

    
    public any function init() {
        variables.UsersDAO = createObject("component", "dao.users_DAO").init();
        return this;
    }

    /**
     * Get a user record with validation and consistent return structure
     */
    public struct function getUser( required numeric userID ) {
        var user = variables.UsersDAO.getUserByID( userID );

        if ( structIsEmpty( user ) ) {
            return { success=false, message="User not found.", data={} };
        }

        return { success=true, data=user };
    }

    public struct function getUserByCougarnet( required string cougarnetID ) {
        var user = variables.UsersDAO.getUserByCougarnet( trim(arguments.cougarnetID) );

        if ( structIsEmpty( user ) ) {
            return { success=false, message="User not found.", data={} };
        }

        return { success=true, data=user };
    }

    /**
     * Create a user with validation and normalization
     */
    public struct function createUser( required struct data ) {

        // Normalize
        data.EmailPrimary = len( data.EmailPrimary ?: "" ) ? trim( lCase( data.EmailPrimary ) ) : "";
        data.FirstName = trim( data.FirstName );
        data.LastName = trim( data.LastName );
        data.Title1 = trim( data.Title1 ?: "" );
        data.Title2 = trim( data.Title2 ?: "" );
        data.Title3 = trim( data.Title3 ?: "" );
        data.Room = trim( data.Room ?: "" );
        data.Building = trim( data.Building ?: "" );
        data.Prefix = trim( data.Prefix ?: "" );
        data.Suffix = trim( data.Suffix ?: "" );
        data.Degrees = trim( data.Degrees ?: "" );
        data.Campus = trim( data.Campus ?: "" );
        data.Division = trim( data.Division ?: "" );
        data.DivisionName = trim( data.DivisionName ?: "" );
        data.Department = trim( data.Department ?: "" );
        data.DepartmentName = trim( data.DepartmentName ?: "" );
        data.Office_Mailing_Address = trim( data.Office_Mailing_Address ?: "" );
        data.Mailcode = trim( data.Mailcode ?: "" );

        // Validate
        if ( !len( data.FirstName ) OR !len( data.LastName ) ) {
            return { success=false, message="First and last name are required." };
        }

        if ( len( data.EmailPrimary ) && !isValid( "email", data.EmailPrimary ) ) {
            return { success=false, message="Primary email is invalid." };
        }

        // Create
        var newID = variables.UsersDAO.createUser( data );

        return {
            success=true,
            message="User created.",
            userID=newID
        };
    }

    /**
     * Update a user with validation
     */
    public struct function updateUser( required numeric userID, required struct data ) {
        data.Title1 = trim( data.Title1 ?: "" );
        data.Title2 = trim( data.Title2 ?: "" );
        data.Title3 = trim( data.Title3 ?: "" );
        data.Room = trim( data.Room ?: "" );
        data.Building = trim( data.Building ?: "" );
        data.Prefix = trim( data.Prefix ?: "" );
        data.Suffix = trim( data.Suffix ?: "" );
        data.Degrees = trim( data.Degrees ?: "" );
        data.Campus = trim( data.Campus ?: "" );
        data.Division = trim( data.Division ?: "" );
        data.DivisionName = trim( data.DivisionName ?: "" );
        data.Department = trim( data.Department ?: "" );
        data.DepartmentName = trim( data.DepartmentName ?: "" );
        data.Office_Mailing_Address = trim( data.Office_Mailing_Address ?: "" );
        data.Mailcode = trim( data.Mailcode ?: "" );

        if ( len( data.EmailPrimary ?: "" ) && !isValid( "email", data.EmailPrimary ) ) {
            return { success=false, message="Invalid primary email." };
        }

        variables.UsersDAO.updateUser( userID, data );

        return { success=true, message="User updated." };
    }

    public void function updateDegreesField( required numeric userID, required string degrees ) {
        variables.UsersDAO.updateDegreesField( userID, degrees );
    }

    public void function updateTitle1Field( required numeric userID, required string title1 ) {
        variables.UsersDAO.updateTitle1Field( userID, trim(arguments.title1 ?: "") );
    }

    /**
     * Delete a user and all related records
     */
    public struct function deleteUser( required numeric userID ) {
        var user = variables.UsersDAO.getUserByID( userID );
        
        if ( structIsEmpty( user ) ) {
            return { success=false, message="User not found." };
        }

        variables.UsersDAO.deleteUser( userID );

        return { 
            success=true, 
            message="User #user.FIRSTNAME# #user.LASTNAME# has been permanently deleted along with all associated records." 
        };
    }

    
    public array function listUsers() {
        return variables.UsersDAO.getAllUsers();
    }

    public struct function searchUsers(
        string searchTerm   = "",
        string filterFlag   = "",
        string filterOrg    = "",
        string filterClass  = "",
        string excludeFlags = "",
        string excludeOrgs  = "",
        numeric maxRows     = 50,
        numeric startRow    = 1
    ) {
        return variables.UsersDAO.searchUsers(
            searchTerm   = arguments.searchTerm,
            filterFlag   = arguments.filterFlag,
            filterOrg    = arguments.filterOrg,
            filterClass  = arguments.filterClass,
            excludeFlags = arguments.excludeFlags,
            excludeOrgs  = arguments.excludeOrgs,
            maxRows      = arguments.maxRows,
            startRow     = arguments.startRow
        );
    }

}