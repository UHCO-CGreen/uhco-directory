component extends="dao.BaseDAO" output="false" singleton {

    public any function init() {
        super.init();
        return this;
    }

    public array function getAppointments( required numeric userID ) {
        var qry = executeQueryWithRetry(
            "SELECT * FROM UserAppointments WHERE UserID = :id ORDER BY SortOrder, AppointmentID",
            { id={ value=userID, cfsqltype="cf_sql_integer" } },
            { datasource=variables.datasource, timeout=30, fetchSize=100 }
        );
        return queryToArray(qry);
    }

    public void function replaceAppointments( required numeric userID, required array appointments ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry(
            "DELETE FROM UserAppointments WHERE UserID = :id",
            idParam, { datasource=variables.datasource, timeout=30 }
        );
        var sortIdx = 0;
        for ( var appt in arguments.appointments ) {
            var appointmentName = appt.appointmentName ?: "";
            var appointmentType = appt.appointmentType ?: "";

            executeQueryWithRetry(
                "INSERT INTO UserAppointments (UserID, AppointmentName, AppointmentType, SortOrder)
                 VALUES (:id, :AppointmentName, :AppointmentType, :SortOrder)",
                {
                    id              = { value=userID,          cfsqltype="cf_sql_integer"  },
                    AppointmentName = { value=appointmentName,  cfsqltype="cf_sql_nvarchar", null=(len(appointmentName) EQ 0) },
                    AppointmentType = { value=appointmentType,  cfsqltype="cf_sql_nvarchar", null=(len(appointmentType) EQ 0) },
                    SortOrder       = { value=sortIdx,          cfsqltype="cf_sql_integer"  }
                },
                { datasource=variables.datasource, timeout=30 }
            );
            sortIdx++;
        }
    }

    public void function deleteAllForUser( required numeric userID ) {
        var idParam = { id={ value=userID, cfsqltype="cf_sql_integer" } };
        executeQueryWithRetry( "DELETE FROM UserAppointments WHERE UserID = :id", idParam, { datasource=variables.datasource, timeout=30 } );
    }
}
