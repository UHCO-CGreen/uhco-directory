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

    public struct function getPublishedImages() {
        var images = variables.ImagesDAO.getPublishedImages();

        for ( var i = 1; i LTE arrayLen(images); i++ ) {
            if ( structKeyExists(images[i], "IMAGEURL") ) {
                images[i].IMAGEURL = variables.MediaConfigService.normalizePublishedUrl( images[i].IMAGEURL ?: "" );
            }
        }

        return { success=true, data=images };
    }

    public struct function getPublishedVariantList() {
        var rows = variables.ImagesDAO.getPublishedVariantList();
        var variants = [];

        for ( var row in rows ) {
            if ( len(trim(row.IMAGEVARIANT ?: "")) ) {
                arrayAppend(variants, trim(row.IMAGEVARIANT));
            }
        }

        return { success=true, data=variants };
    }

    public struct function getPublishedUserSummaryCount( string searchTerm = "", string variantFilter = "" ) {
        return {
            success = true,
            data = variables.ImagesDAO.getPublishedUserSummaryCount(
                searchTerm = arguments.searchTerm,
                variantFilter = arguments.variantFilter
            )
        };
    }

    public struct function getPublishedUserSummaryPage(
        numeric pageSize = 25,
        numeric pageNumber = 1,
        string searchTerm = "",
        string variantFilter = ""
    ) {
        var rows = variables.ImagesDAO.getPublishedUserSummaryPage(
            pageSize = arguments.pageSize,
            pageNumber = arguments.pageNumber,
            searchTerm = arguments.searchTerm,
            variantFilter = arguments.variantFilter
        );

        for ( var i = 1; i LTE arrayLen(rows); i++ ) {
            rows[i].WEBTHUMBURL = variables.MediaConfigService.normalizePublishedUrl( rows[i].WEBTHUMBURL ?: "" );
            rows[i].WEBPROFILEURL = variables.MediaConfigService.normalizePublishedUrl( rows[i].WEBPROFILEURL ?: "" );
            rows[i].LEGACYALUMNIURL = variables.MediaConfigService.normalizePublishedUrl( rows[i].LEGACYALUMNIURL ?: "" );
        }

        return { success=true, data=rows };
    }

    public struct function getPublishedImageCountMapByUser() {
        var rows = variables.ImagesDAO.getPublishedImageCountsByUser();
        var result = {};

        for (var row in rows) {
            result[ toString(row.USERID) ] = val(row.PUBLISHEDCOUNT ?: 0);
        }

        return { success=true, data=result };
    }

    public struct function getPublishedImageTotalCount() {
        return {
            success = true,
            data = variables.ImagesDAO.getPublishedImageTotalCount()
        };
    }

    public struct function getNeedsPublishingUserCount() {
        return {
            success = true,
            data = variables.ImagesDAO.getNeedsPublishingUserCount()
        };
    }

    public struct function getNeedsPublishingQueue() {
        return {
            success = true,
            data = variables.ImagesDAO.getNeedsPublishingQueue()
        };
    }

}