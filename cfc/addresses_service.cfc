component output="false" singleton {

    public any function init() {
        variables.AddressesDAO = createObject("component", "dir.dao.addresses_DAO").init();
        return this;
    }

    public struct function getAddresses( required numeric userID ) {
        return { success=true, data=variables.AddressesDAO.getAddresses( userID ) };
    }

    public struct function addAddress( required struct data ) {

        // Business rule example:
        // Building codes must be uppercase
        if ( structKeyExists( data, "Building" ) ) {
            data.Building = uCase( trim( data.Building ) );
        }

        var id = variables.AddressesDAO.createAddress( data );

        return { success=true, addressID=id };
    }

    public struct function deleteAddress( required numeric addressID ) {
        variables.AddressesDAO.deleteAddress( addressID );
        return { success=true };
    }

}