#!/usr/bin/env bash
#
# https://github.com/P3TERX/aria2.conf
# File name：upload.sh
# Description: Use Rclone to upload files after Aria2 download is complete
# Version: 3.1
#
# Copyright (c) 2018-2021 P3TERX <https://p3terx.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

CHECK_CORE_FILE() {
    CORE_FILE="$(dirname $0)/core"
    if [[ -f "${CORE_FILE}" ]]; then
        . "${CORE_FILE}"
    else
        echo && echo "!!! core file does not exist !!!"
        exit 1
    fi
}

CHECK_RCLONE() {
    [[ $# -eq 0 ]] && {
        echo && echo -e "Checking RCLONE connection ..."
        rclone mkdir "${DRIVE_NAME}:${DRIVE_DIR}/P3TERX.COM"
        if [[ $? -eq 0 ]]; then
            rclone rmdir "${DRIVE_NAME}:${DRIVE_DIR}/P3TERX.COM"
            echo
            echo -e "${LIGHT_GREEN_FONT_PREFIX}success${FONT_COLOR_SUFFIX}"
            exit 0
        else
            echo
            echo -e "${RED_FONT_PREFIX}failure${FONT_COLOR_SUFFIX}"
            exit 1
        fi
    }
}

TASK_INFO() {
    echo -e "
-------------------------- [${YELLOW_FONT_PREFIX}Task Infomation${FONT_COLOR_SUFFIX}] --------------------------
${LIGHT_PURPLE_FONT_PREFIX}Task GID:${FONT_COLOR_SUFFIX} ${TASK_GID}
${LIGHT_PURPLE_FONT_PREFIX}Number of Files:${FONT_COLOR_SUFFIX} ${FILE_NUM}
${LIGHT_PURPLE_FONT_PREFIX}First File Path:${FONT_COLOR_SUFFIX} ${FILE_PATH}
${LIGHT_PURPLE_FONT_PREFIX}Task File Name:${FONT_COLOR_SUFFIX} ${TASK_FILE_NAME}
${LIGHT_PURPLE_FONT_PREFIX}Task Path:${FONT_COLOR_SUFFIX} ${TASK_PATH}
${LIGHT_PURPLE_FONT_PREFIX}Aria2 Download Directory:${FONT_COLOR_SUFFIX} ${ARIA2_DOWNLOAD_DIR}
${LIGHT_PURPLE_FONT_PREFIX}Custom Download Directory:${FONT_COLOR_SUFFIX} ${DOWNLOAD_DIR}
${LIGHT_PURPLE_FONT_PREFIX}Local Path:${FONT_COLOR_SUFFIX} ${LOCAL_PATH}
${LIGHT_PURPLE_FONT_PREFIX}Remote Path:${FONT_COLOR_SUFFIX} ${REMOTE_PATH}
${LIGHT_PURPLE_FONT_PREFIX}.aria2 File Path:${FONT_COLOR_SUFFIX} ${DOT_ARIA2_FILE}
-------------------------- [${YELLOW_FONT_PREFIX}Task Infomation${FONT_COLOR_SUFFIX}] --------------------------
"
}

OUTPUT_UPLOAD_LOG() {
    LOG="${UPLOAD_LOG}"
    LOG_PATH="${UPLOAD_LOG_PATH}"
    OUTPUT_LOG
}

DEFINITION_PATH() {
    LOCAL_PATH="${TASK_PATH}"
    if [[ -f "${TASK_PATH}" ]]; then
        REMOTE_PATH="${DRIVE_NAME}:${DRIVE_DIR}${DEST_PATH_SUFFIX%/*}"
    else
        REMOTE_PATH="${DRIVE_NAME}:${DRIVE_DIR}${DEST_PATH_SUFFIX}"
    fi
}

LOAD_RCLONE_ENV() {
    RCLONE_ENV_FILE="${ARIA2_CONF_DIR}/rclone.env"
    [[ -f ${RCLONE_ENV_FILE} ]] && export $(grep -Ev "^#|^$" ${RCLONE_ENV_FILE} | xargs -0)
}

UPLOAD_FILE() {
    echo -e "$(DATE_TIME) ${INFO} Start upload files..."
    TASK_INFO
    RETRY=0
    RETRY_NUM=3
    while [ ${RETRY} -le ${RETRY_NUM} ]; do
        [ ${RETRY} != 0 ] && (
            echo
            echo -e "$(DATE_TIME) ${ERROR} Upload failed! Retry ${RETRY}/${RETRY_NUM} ..."
            echo
        )
        rclone move -v "${LOCAL_PATH}" "${REMOTE_PATH}"
        RCLONE_EXIT_CODE=$?
        if [ ${RCLONE_EXIT_CODE} -eq 0 ]; then
            UPLOAD_LOG="$(DATE_TIME) ${INFO} Upload done: ${LOCAL_PATH} -> ${REMOTE_PATH}"
            OUTPUT_UPLOAD_LOG
            DELETE_EMPTY_DIR
            break
        else
            RETRY=$((${RETRY} + 1))
            [ ${RETRY} -gt ${RETRY_NUM} ] && (
                echo
                UPLOAD_LOG="$(DATE_TIME) ${ERROR} Upload failed: ${LOCAL_PATH}"
                OUTPUT_UPLOAD_LOG
            )
            sleep 3
        fi
    done
}


#注：
#1.编辑/root/.aria2c/aria2.conf，找到“下载完成后执行的命令”，把clean.sh替换为upload.sh，即on-download-complete=/root/.aria2c/upload.sh
#2.编辑/root/.aria2c/aria2.conf，找到“最大同时下载任务数”, 修改为3，即max-concurrent-downloads=3
#3.编辑/root/.aria2c/script.conf，找到“网盘名称”，改为drive-name=rclone_onedrive    (即RCLONE 配置时填写的 name)
#4.编辑/root/.aria2c/script.conf，找到“网盘目录”，去掉注释符"#"，目录改为drive-dir=/aria2/Download
#重启
#安装rclone，然后输入命令行输入rclone config 命令进入交互式配置选项（或直接拷贝已有配置文件rclone.conf至/root/.config/rclone）
#执行upload.sh脚本（执行原版脚本而不是本修改后的脚本），提示success即代上传脚本能正常被调用，否则请检查与 RCLONE 有关的配置。
#将原版脚本upload.sh替换为本脚本upload.sh

#注：
#1.把rclone.env中RCLONE_TRANSFERS设置为1，记得把注释#删掉
#2.修改aria2的最大同时下载任务数，即把aria2.conf中max-concurrent-downloads改为3
#3.可以设置不进入队列的文件大小FILE_SIZE_LIMIT_OF_NO_QUEUE，默认为10M，但文件夹一定进入队列
#4.可以设置rclone上传任务的并行数量MAX_RCLONE_UPLOAD_NUM，默认为2,该参数只能控制rclone的任务数量，不能控制rclone单个任务中同时上传的文件数量，同时上传的文件数量通过rclone.env中的RCLONE_TRANSFERS参数控制
WAIT_IN_QUEUE() {
    #不进入队列的文件大小，小于该值的时候直接上传无需排队，单位为M
    FILE_SIZE_LIMIT_OF_NO_QUEUE=10
    #FILE_SIZE_OF_NOW_TASK=$(wc -c ${LOCAL_PATH} | tr -cd "[0-9]")
    FILE_SIZE_OF_NOW_TASK=$(wc -c "${LOCAL_PATH}" | cut -d" " -f1)
    
    #任务队列执行日志
    #echo "${LOCAL_PATH}  ${FILE_SIZE_OF_NOW_TASK}" >> /root/.aria2c/rcloneTasklog.log
    
    #文件大小小于限定值并且大于0时直接上传无需排队
    #文件大小等于0时，即任务为文件夹时，必须排队；大于限定值时，要排队
    if [ ${FILE_SIZE_OF_NOW_TASK} -le $[ ${FILE_SIZE_LIMIT_OF_NO_QUEUE} * 1024 * 1024 ] -a ${FILE_SIZE_OF_NOW_TASK} -gt 0 ]
    then
        return 0
    fi


    #rclone上传任务的并行数量
    #只能控制rclone的任务数量，不能控制rclone单个任务中同时上传的文件数量
    #所以为了避免内存爆满，最好把rclone.env中RCLONE_TRANSFERS设置为1
    MAX_RCLONE_UPLOAD_NUM=2
    
    #当前上传任务的唯一标识符
    TASK_UUID=$[16#$(cat /dev/random | head -n 10 | md5sum | head -c 10)]
    
    #队列文件绝对路径，存放所有尚未完成的rclone任务队列对应的UUID
    QUEUE_FILE="/root/.aria2c/rcloneTaskQueue.dat"
    
    #将当前上传任务(的唯一标识符)加入队列 
    test -s $QUEUE_FILE && sed -i '$a '${TASK_UUID} $QUEUE_FILE || echo $TASK_UUID >> $QUEUE_FILE
    sleep 3s
    
    taskStart=0
    while [ ${taskStart} -eq 0 ]
    do
        count=1
        while read line
        do
            if [ $TASK_UUID -eq $line ]
            then
                #echo "上传任务开始"
                taskStart=1
                break
            fi
            
            count=$[ $count + 1 ]
            if [ ${count} -gt ${MAX_RCLONE_UPLOAD_NUM} ]
            then
                break
            fi
            
        done < ${QUEUE_FILE}
        
        sleep 30s
    done
    
    #删除无用变量
    unset MAX_RCLONE_UPLOAD_NUM
    unset taskStart
    unset line
}

QUIT_QUEUE() {
    if [ ${FILE_SIZE_OF_NOW_TASK} -le $[ ${FILE_SIZE_LIMIT_OF_NO_QUEUE} * 1024 * 1024 ] -a ${FILE_SIZE_OF_NOW_TASK} -gt 0 ]
    then
        return 0
    fi
    
    sleep 5s
    #执行完毕，删除队列中当前上传任务的唯一标识符
    sed -i "/^${TASK_UUID}$/d" ${QUEUE_FILE}
}


CHECK_CORE_FILE "$@"
CHECK_SCRIPT_CONF
CHECK_RCLONE "$@"
CHECK_FILE_NUM
GET_TASK_INFO
GET_DOWNLOAD_DIR
CONVERSION_PATH
DEFINITION_PATH
CLEAN_UP
LOAD_RCLONE_ENV
WAIT_IN_QUEUE
UPLOAD_FILE
QUIT_QUEUE

exit 0
