/**
 *  SMZipArchive.m
 *  ShareGlobal
 *
 *  Created by huangxp on 12-12-05.
 *
 *  zip压缩工具
 *  借鉴网上压缩SMZipArchive工程
 *
 *  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
 */

#import "SMZipArchive.h"
#import "unzip.h"
#import "zip.h"

#define kZipExtractionBufferSize 4096

@interface SMZipArchive()
{
    zipFile _zipFile;
}
@end

@implementation SMZipArchive
@synthesize password = _password;
@synthesize archiveItems = _archiveItems;

- (id)init
{
	if((self = [super init]))
	{
		_zipFile = NULL;
        _archiveItems = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
    [self closeZipArchive]; 
}

- (BOOL)createZipArchive:(NSString *)zipPath
{
    _zipFile = sm_zipOpen((const char*)[zipPath UTF8String], 0);
	if(!_zipFile)
		return NO;
	return YES;
}

- (BOOL)createZipArchive:(NSString *)zipPath password:(NSString *)password
{
    self.password = password;
    return [self createZipArchive:zipPath];
}

- (BOOL)addFileToZip:(NSString *)filePath newName:(NSString *)newName
{
	if(!_zipFile)
		return NO;
//	tm_zip filetime;
	time_t current;
	time(&current);
	
	zip_fileinfo zipInfo = {0};
//	zipInfo.dosDate = (unsigned long) current;
	NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
	if(attr)
	{
		NSDate *fileDate = (NSDate*)[attr objectForKey:NSFileModificationDate];
		if(fileDate)
		{
			// some application does use dosDate, but tmz_date instead
            //	zipInfo.dosDate = [fileDate timeIntervalSinceDate:[self Date1980] ];
			NSCalendar* currCalendar = [NSCalendar currentCalendar];
			uint flags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit |
            NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ;
			NSDateComponents* dc = [currCalendar components:flags fromDate:fileDate];
			zipInfo.tmz_date.tm_sec = [dc second];
			zipInfo.tmz_date.tm_min = [dc minute];
			zipInfo.tmz_date.tm_hour = [dc hour];
			zipInfo.tmz_date.tm_mday = [dc day];
			zipInfo.tmz_date.tm_mon = [dc month] - 1;
			zipInfo.tmz_date.tm_year = [dc year];
		}
	}
	
	int ret ;
	NSData *data = nil;
	if([_password length] == 0)
	{
		ret = sm_zipOpenNewFileInZip(_zipFile,
								  (const char*)[newName UTF8String],
								  &zipInfo,
								  NULL,0,
								  NULL,0,
								  NULL,//comment
								  Z_DEFLATED,
								  Z_DEFAULT_COMPRESSION );
	}
	else
	{
		data = [NSData dataWithContentsOfFile:filePath];
		uLong crcValue = crc32( 0L,NULL, 0L );
		crcValue = crc32(crcValue,(const Bytef*)[data bytes], [data length]);
		ret = sm_zipOpenNewFileInZip3(_zipFile,
                                   (const char*)[newName UTF8String],
                                   &zipInfo,
                                   NULL,0,
                                   NULL,0,
                                   NULL,//comment
                                   Z_DEFLATED,
                                   Z_DEFAULT_COMPRESSION,
                                   0,
                                   15,
                                   8,
                                   Z_DEFAULT_STRATEGY,
                                   [_password cStringUsingEncoding:NSASCIIStringEncoding],
                                   crcValue );
	}
	if(ret != Z_OK)
	{
		return NO;
	}
	if(data == nil)
	{
		data = [NSData dataWithContentsOfFile:filePath];
	}
	unsigned int dataLen = [data length];
	ret = sm_zipWriteInFileInZip(_zipFile, (const void*)[data bytes], dataLen);
	if(ret!=Z_OK)
	{
		return NO;
	}
	ret = sm_zipCloseFileInZip(_zipFile);
	if(ret!=Z_OK)
		return NO;
    [_archiveItems addObject:filePath];
	return YES;
}

- (BOOL)closeZipArchive
{
	_password = nil;
	if(_zipFile == NULL)
		return NO;
	BOOL ret =  sm_zipClose(_zipFile,NULL)==Z_OK?YES:NO;
	_zipFile = NULL;
	return ret;
}

@end

@interface SMUnzipArchive()
{
    void      *_unzFile;
    NSData    * _data;
    long      _offset;
}
@end

@implementation SMUnzipArchive
@synthesize password = _password;
@synthesize skipInvisibleFiles = _skipInvisible;

+ (BOOL)unzipArchiveAtPath:(NSString*)inPath toPath:(NSString*)outPath
{
    return [self unzipArchiveAtPath:inPath toPath:outPath password:nil];
}

+ (BOOL)unzipArchiveAtPath:(NSString *)inPath toPath:(NSString *)outPath password:(NSString *)password
{
    BOOL success = NO;
    SMUnzipArchive* archive = [[SMUnzipArchive alloc] initWithArchiveAtPath:inPath];
    archive.password = password;
    if (archive)
    {
        success = [archive unzipToPath:outPath];
    }
    return success;
}

+ (BOOL)unzipArchiveData:(NSData*)inData toPath:(NSString*)outPath
{
    return [self unzipArchiveData:inData toPath:outPath password:nil];
}

+ (BOOL)unzipArchiveData:(NSData *)inData toPath:(NSString *)outPath password:(NSString *)password
{
    BOOL success = NO;
    SMUnzipArchive* archive = [[SMUnzipArchive alloc] initWithArchiveData:inData];
    archive.password = password;
    if (archive)
    {
        success = [archive unzipToPath:outPath];
    }
    return success;
}

- (id)initWithUnzFile:(unzFile)file
{
    if (file == NULL)
    {
        return nil;
    }
    if ((self = [super init]))
    {
        _unzFile = file;
    }
    return self;
}

- (void)dealloc
{
    if (_unzFile)
    {
      sm_unzClose(_unzFile);
    }
}

- (id)initWithArchiveAtPath:(NSString*)path
{
    return [self initWithUnzFile:sm_unzOpen([path UTF8String])];
}

static voidpf _OpenFunction(voidpf opaque, const char* filename, int mode)
{
    return opaque;  // This becomes the "stream" argument for the other callbacks
}

static uLong _ReadFunction(voidpf opaque, voidpf stream, void* buf, uLong size)
{
    SMUnzipArchive* zip = (__bridge SMUnzipArchive*)opaque;
    const void* bytes = zip->_data.bytes;
    long length = zip->_data.length;
    size = MIN(size, length - zip->_offset);
    if (size)
    {
        bcopy((char*)bytes + zip->_offset, buf, size);
        zip->_offset += size;
    }
    return size;
}

static long _TellFuntion(voidpf opaque, voidpf stream)
{
    SMUnzipArchive* zip = (__bridge SMUnzipArchive*)opaque;
    return zip->_offset;
}

static long _SeekFunction(voidpf opaque, voidpf stream, uLong offset, int origin)
{
    SMUnzipArchive* zip = (__bridge SMUnzipArchive*)opaque;
    long length = zip->_data.length;
    switch (origin)
    {
        case ZLIB_FILEFUNC_SEEK_CUR:
            zip->_offset += offset;
            break;
        case ZLIB_FILEFUNC_SEEK_END:
            zip->_offset = length + offset;
            break;
        case ZLIB_FILEFUNC_SEEK_SET:
            zip->_offset = offset;
            break;
    }
    return (zip->_offset >= 0) && (zip->_offset <= length) ? 0 : -1;
}

static int _CloseFunction(voidpf opaque, voidpf stream)
{
    return 0;
}

static int _ErrorFunction(voidpf opaque, voidpf stream)
{
    return 0;
}

- (id)initWithArchiveData:(NSData*)data
{
    _data = [data copy];  // -initWithUnzFile: will call -release on error
  
    zlib_filefunc_def functions;
    functions.zopen_file = _OpenFunction;
    functions.zread_file = _ReadFunction;
    functions.zwrite_file = NULL;
    functions.ztell_file = _TellFuntion;
    functions.zseek_file = _SeekFunction;
    functions.zclose_file = _CloseFunction;
    functions.zerror_file = _ErrorFunction;
    functions.opaque = (__bridge voidpf)(self);
    return [self initWithUnzFile:sm_unzOpen2(NULL, &functions)];
}

- (NSArray*)retrieveFileList
{
    NSMutableArray *array = [NSMutableArray array];
  
    // Set current file to first file in archive
    int result = sm_unzGoToFirstFile(_unzFile);
    while (1)
    {
        // Open current file
        if (result == UNZ_OK)
        {
            result = sm_unzOpenCurrentFile(_unzFile);
        }
        if (result != UNZ_OK)
        {
            if (result != UNZ_END_OF_LIST_OF_FILE)
            {
                array = nil;
            }
            break;
        }
    
        // Retrieve current file path and convert path separators if needed
        unz_file_info fileInfo = {0};
        result = sm_unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
        if (result != UNZ_OK)
        {
            sm_unzCloseCurrentFile(_unzFile);
            array = nil;
            break;
        }
        char* filename = (char*)malloc(fileInfo.size_filename + 1);
        sm_unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename, NULL, 0, NULL, 0);
        for (unsigned int i = 0; i < fileInfo.size_filename; ++i)
        {
            if (filename[i] == '\\')
            {
                filename[i] = '/';
            }
        }
        filename[fileInfo.size_filename] = 0;
        NSString* path = [NSString stringWithUTF8String:filename];
        free(filename);
        
        // Add current file to list if necessary
        if (_skipInvisible)
        {
            for (NSString* string in [path pathComponents])
            {
                if ([string hasPrefix:@"."])
                {
                    path = nil;
                    break;
                }
            }
        }
        if (path && ![path hasSuffix:@"/"])
        {
            [array addObject:path];
        }
        
        // Close current file and go to next one
        sm_unzCloseCurrentFile(_unzFile);
        result = sm_unzGoToNextFile(_unzFile);
    }
    return array;
}

// See do_extract_currentfile() from miniunz.c for reference
- (BOOL)unzipToPath:(NSString*)outPath
{
    BOOL success = YES;
    NSFileManager *manager = [NSFileManager defaultManager];
  
    // Set current file to first file in archive
    int result = sm_unzGoToFirstFile(_unzFile);
    while (1)
    {
        // Open current file
        if (result == UNZ_OK)
        {
            if ([self.password length] == 0)
            {
                result = sm_unzOpenCurrentFile(_unzFile);
            }
            else
            {
                result = sm_unzOpenCurrentFilePassword(_unzFile, [self.password cStringUsingEncoding:NSASCIIStringEncoding]);
            }
        }
        if (result != UNZ_OK)
        {
            if (result != UNZ_END_OF_LIST_OF_FILE)
            {
                success = NO;
            }
            break;
        }
    
        // Retrieve current file path and convert path separators if needed
        unz_file_info fileInfo = {0};
        result = sm_unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
        if (result != UNZ_OK)
        {
            sm_unzCloseCurrentFile(_unzFile);
            success = NO;
            break;
        }
        char* filename = (char*)malloc(fileInfo.size_filename + 1);
        sm_unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename, NULL, 0, NULL, 0);
        for (unsigned int i = 0; i < fileInfo.size_filename; ++i)
        {
            if (filename[i] == '\\')
            {
                filename[i] = '/';
            }
        }
        filename[fileInfo.size_filename] = 0;
        NSString* path = [NSString stringWithUTF8String:filename];
        free(filename);
    
        // Extract current file
        if (_skipInvisible)
        {
            for (NSString* string in [path pathComponents])
            {
                if ([string hasPrefix:@"."])
                {
                    path = nil;
                    break;
                }
            }
        }
        if (path)
        {
            NSString* fullPath = [outPath stringByAppendingPathComponent:path];
      
            // If current file is actually a directory, create it
            if ([path hasSuffix:@"/"])
            {
                NSError* error = nil;
                if (![manager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:&error])
                {
                    success = NO;
                }
            }
            // Otherwise extract file
            else
            {
                FILE* outFile = fopen((const char*)[fullPath UTF8String], "w+");
                if (outFile == NULL)
                {
                    [manager createDirectoryAtPath:[fullPath stringByDeletingLastPathComponent]withIntermediateDirectories:YES attributes:nil error:nil];
                    outFile = fopen((const char*)[fullPath UTF8String], "w+");  // Some zip files don't contain directory alone before file
                }
                if (outFile)
                {
                    while (1)
                    {
                        unsigned char buffer[kZipExtractionBufferSize];
                        int read = sm_unzReadCurrentFile(_unzFile, buffer, kZipExtractionBufferSize);
                        if (read > 0)
                        {
                            if (fwrite(buffer, read, 1, outFile) != 1)
                            {
                                success = NO;
                                break;
                            }
                        }
                        else if (read < 0)
                        {
                            success = NO;
                            break;
                        }
                        else
                        {
                            break;
                        }
                    }
                    fclose(outFile);
                }
                else
                {
                    success = NO;
                }
            }
        }
    
        // Close current file and go to next one
        sm_unzCloseCurrentFile(_unzFile);
        if (!success)
        {
            break;
        }
        result = sm_unzGoToNextFile(_unzFile);
    }
    return success;
}

- (BOOL)unzipFile:(NSString*)inPath toPath:(NSString*)outPath
{
    BOOL success = NO;
  
    // Set current file to first file in archive
    int result = sm_unzGoToFirstFile(_unzFile);
    while (1)
    {
        // Open current file
        if (result == UNZ_OK)
        {
            if (result == UNZ_OK)
            {
                if ([self.password length] == 0)
                {
                    result = sm_unzOpenCurrentFile(_unzFile);
                }
                else
                {
                    result = sm_unzOpenCurrentFilePassword(_unzFile, [self.password cStringUsingEncoding:NSASCIIStringEncoding]);
                }
            }
        }
        if (result != UNZ_OK)
        {
            if (result != UNZ_END_OF_LIST_OF_FILE)
            {
            }
            break;
        }
    
        // Retrieve current file path and convert path separators if needed
        unz_file_info fileInfo = {0};
        result = sm_unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
        if (result != UNZ_OK)
        {
            sm_unzCloseCurrentFile(_unzFile);
            break;
        }
        char* filename = (char*)malloc(fileInfo.size_filename + 1);
        sm_unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename, NULL, 0, NULL, 0);
        for (unsigned int i = 0; i < fileInfo.size_filename; ++i)
        {
            if (filename[i] == '\\')
            {
                filename[i] = '/';
            }
        }
        filename[fileInfo.size_filename] = 0;
        NSString* path = [NSString stringWithUTF8String:filename];  // TODO: Is this correct?
        free(filename);
        
        // If file is required one, extract it
        if (![path hasSuffix:@"/"] && [path isEqualToString:inPath])
        {
            FILE* outFile = fopen((const char*)[outPath UTF8String], "w");
            if (outFile)
            {
                success = YES;
                while (1)
                {
                    unsigned char buffer[kZipExtractionBufferSize];
                    int read = sm_unzReadCurrentFile(_unzFile, buffer, kZipExtractionBufferSize);
                    if (read > 0)
                    {
                        if (fwrite(buffer, read, 1, outFile) != 1)
                        {
                            success = NO;
                            break;
                        }
                    }
                    else if (read < 0)
                    {
                        success = NO;
                        break;
                    }
                    else
                    {
                        break;
                    }
                }
                fclose(outFile);
            }
            else
            {
            }
            sm_unzCloseCurrentFile(_unzFile);
            break;
        }
        // Close current file and go to next one
        sm_unzCloseCurrentFile(_unzFile);
        result = sm_unzGoToNextFile(_unzFile);
      }
      return success;
}

@end
