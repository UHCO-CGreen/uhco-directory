component output="false" singleton {

    public any function init() {
        variables.ImagesDAO = createObject("component", "dir.dao.images_DAO").init();
        return this;
    }

    public struct function getImages( required numeric userID ) {
        return { success=true, data=variables.ImagesDAO.getImages( userID ) };
    }

    public struct function addImage( required struct data ) {

        if ( !len( data.ImageURL ) ) {
            return { success=false, message="ImageURL required." };
        }

        // Business rule: thumbnail must be sort order 0
        if ( data.ImageType == "Thumbnail" ) {
            data.SortOrder = 0;
        }

        var newID = variables.ImagesDAO.addImage( data );

        return { success=true, imageID=newID };
    }

    public struct function deleteImage( required numeric imageID ) {
        variables.ImagesDAO.removeImage( imageID );
        return { success=true };
    }

}