component output="false" singleton {

    public any function init() {
        variables.ImagesDAO = createObject("component", "dao.images_DAO").init();
        variables.MediaConfigService = createObject("component", "cfc.mediaConfig_service").init();
        return this;
    }

    public struct function getImages( required numeric userID ) {
        var images = variables.ImagesDAO.getImages( userID );

        for ( var i = 1; i LTE arrayLen(images); i++ ) {
            if ( structKeyExists(images[i], "IMAGEURL") ) {
                images[i].IMAGEURL = variables.MediaConfigService.normalizePublishedUrl( images[i].IMAGEURL ?: "" );
            }
        }

        return { success=true, data=images };
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

    public struct function getWebThumbMap() {
        var webThumbMap = variables.ImagesDAO.getWebThumbMap();

        for ( var userID in webThumbMap ) {
            webThumbMap[userID] = variables.MediaConfigService.normalizePublishedUrl( webThumbMap[userID] ?: "" );
        }

        return webThumbMap;
    }

}