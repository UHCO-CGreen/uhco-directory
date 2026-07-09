component output="false" singleton {

    public any function init() {
        variables.UserAppointmentsDAO = createObject("component", "dao.userAppointments_DAO").init();
        return this;
    }

    public struct function getAppointments( required numeric userID ) {
        return { success=true, data=variables.UserAppointmentsDAO.getAppointments( userID ) };
    }

    public void function replaceAppointments( required numeric userID, required array appointments ) {
        variables.UserAppointmentsDAO.replaceAppointments( userID, appointments );
    }
}
