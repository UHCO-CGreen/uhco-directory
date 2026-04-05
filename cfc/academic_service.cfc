component output="false" singleton {

    public any function init() {
        variables.AcademicDAO = createObject("component", "dir.dao.academic_DAO").init();
        return this;
    }


    public struct function getAcademicInfo( required numeric userID ) {
        return {
            success=true,
            data=variables.AcademicDAO.getAcademicInfo( userID )
        };
    }

    public struct function getAllAcademicInfoMap() {
        var rows = variables.AcademicDAO.getAllAcademicInfo();
        var result = {};
        for ( var row in rows ) {
            result[ toString( row.USERID ) ] = { CURRENTGRADYEAR=row.CURRENTGRADYEAR, ORIGINALGRADYEAR=row.ORIGINALGRADYEAR };
        }
        return result;
    }

    public struct function updateAcademicInfo( required numeric userID, required struct data ) {

        // Validation: grad year must be realistic
        if ( data.OriginalGradYear lt 1900 OR data.OriginalGradYear gt year( now() ) + 1 ) {
            return { success=false, message="Invalid OriginalGradYear" };
        }

        variables.AcademicDAO.updateAcademicInfo( userID, data );

        return { success=true, message="Academic info updated." };
    }

    public struct function saveAcademicInfo(
        required numeric userID,
        required string  currentGradYear,
        required string  originalGradYear
    ) {
        var currYear = val( trim( arguments.currentGradYear  ) );
        var origYear = val( trim( arguments.originalGradYear ) );

        // Server-side guard: origYear requires currYear
        if ( origYear GT 0 AND currYear EQ 0 ) {
            return { success=false, message="Original Grad Year requires a Current Grad Year." };
        }

        var existing = variables.AcademicDAO.getAcademicInfo( arguments.userID );

        var dataParams = {
            CurrentGradYear  = { value=currYear, cfsqltype="cf_sql_integer", null=(currYear  EQ 0) },
            OriginalGradYear = { value=origYear, cfsqltype="cf_sql_integer", null=(origYear EQ 0) }
        };

        if ( structIsEmpty( existing ) ) {
            if ( currYear EQ 0 AND origYear EQ 0 ) {
                return { success=true };
            }
            dataParams.UserID = { value=arguments.userID, cfsqltype="cf_sql_integer" };
            variables.AcademicDAO.createAcademicInfo( dataParams );
        } else {
            variables.AcademicDAO.updateAcademicInfo( arguments.userID, dataParams );
        }

        return { success=true, message="Academic info saved." };
    }

}