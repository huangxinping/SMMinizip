/**
 *  SMZipArchive.h
 *  ShareMerge
 *
 *  Created by huangxp on 12-12-05.
 *
 *  zip解压缩工具
 *  借鉴网上压缩MiniZip工程
 *
 *  Copyright (c) 2011年 __MyCompanyName__. All rights reserved.
 */

/** @file */	// Doxygen marker

#import <Foundation/Foundation.h>


@interface SMZipArchive : NSObject
{
    NSString *_password;
    NSMutableArray *_archiveItems;
}

/** zip包密码 */
@property(nonatomic,copy)NSString *password;

/** zip包中现在添加的文件列表 */
@property(nonatomic,readonly)NSMutableArray *archiveItems;

/**
 *  @brief  创建zip压缩包
 *
 *  @param      zipPath     zip文件包路径
 *
 *  @return                是否创建包成功
 */
- (BOOL)createZipArchive:(NSString*)zipPath;

/**
 *  @brief  创建zip压缩包
 *
 *  @param      zipPath     zip文件包路径
 *  @param      password    zip文件包密码
 *
 *  @return                是否创建包成功
 */
- (BOOL)createZipArchive:(NSString*)zipPath password:(NSString*)password;

/**
 *  @brief  添加文件到zip包中
 *
 *  @param      filePath    文件路径
 *  @param      newName     文件在zip包中的名称
 *
 *  @return                是否添加文件成功
 */
- (BOOL)addFileToZip:(NSString*)filePath newName:(NSString*)newName;

/**
 *  @brief  关闭zip包并合并
 *
 *  @return                是否关闭成功
 */
- (BOOL)closeZipArchive;

@end

@interface SMUnzipArchive : NSObject 
{
    BOOL _skipInvisible;
    NSString *_password;
}

/** 是否跳过zip中隐藏文件 */
@property(nonatomic,assign)BOOL skipInvisibleFiles;

/** zip包密码 */
@property(nonatomic,copy)NSString *password;

/**
 *  @brief  解压文件
 *
 *  @param      inPath     zip输入路径
 *  @param      outpath    zip输出路径
 *
 *  @return                是否解压缩成功
 */
+ (BOOL)unzipArchiveAtPath:(NSString*)inPath toPath:(NSString*)outPath;

/**
 *  @brief  解压文件
 *
 *  @param      inPath     zip输入路径
 *  @param      outpath    zip输出路径
 *  @param      password   zip包密码
 *
 *  @return                是否解压缩成功
 */
+ (BOOL)unzipArchiveAtPath:(NSString*)inPath toPath:(NSString*)outPath password:(NSString*)password;

/**
 *  @brief  解压文件
 *
 *  @param      inData     zip输入数据
 *  @param      outpath    zip输出路径
 *
 *  @return                是否解压缩成功
 */
+ (BOOL)unzipArchiveData:(NSData*)inData toPath:(NSString*)outPath;

/**
 *  @brief  解压文件
 *
 *  @param      inData     zip输入数据
 *  @param      outpath    zip输出路径
 *  @param      password   zip包密码
 *
 *  @return                是否解压缩成功
 */
+ (BOOL)unzipArchiveData:(NSData*)inData toPath:(NSString*)outPath password:(NSString*)password;

/**
 *  @brief  初始化zip文件
 *
 *  @param      inPath     zip源路径
 *
 *  @return                对象
 */
- (id)initWithArchiveAtPath:(NSString*)inPath;

/**
 *  @brief  初始化zip文件
 *
 *  @param      inPath     zip源数据
 *
 *  @return                对象
 */
- (id)initWithArchiveData:(NSData*)data;

/**
 *  @brief  获取zip中文件列表
 *
 *  @return                文件列表数组
 */
- (NSArray*)retrieveFileList;

/**
 *  @brief  解压缩整个zip包到路径
 *
 *  @return                是否解压成功
 */
- (BOOL)unzipToPath:(NSString*)outPath;

/**
 *  @brief  解压缩某个文件到某个路径
 *
 *  @param      fileName   zip包中某个文件名称
 *  @param      outPath    输出路径（必须包含完整的文件名）
 *
 *  @return                是否解压成功
 */
- (BOOL)unzipFile:(NSString*)fileName toPath:(NSString*)outPath;

@end 
