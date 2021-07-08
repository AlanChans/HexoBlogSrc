---
title: 多路IO转接服务器
tags:
  - 并发
  - select
  - poll
  - epoll
categories:
  - 多路IO
date: 2021-07-09 00:37:26
---
# 多路IO转接服务器

多路IO转接服务器也叫多任务IO服务器。该类服务器的主要思想是，不再由应用程序自己监视客户端连接，而是交给**内核**去替代应用程序监视文件。

主要使用的方法有三种：select、poll、epoll。

## select

1. select能监听的文件描述符个数受限于FD_SIZE，一般为1024，**单纯改变进程打开的文件描述符个数并不能改变select监听文件的个数**。
2. 解决1024以下客户端使用select是很合适的，但如果连接的客户端数量过多，select采用的是**轮询模式**，会大大降低服务器响应效率。

```c
/* According to POSIX.1-2001, POSIX.1-2008 */
#include <sys/select.h>

/* According to earlier standards */
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

int select(int nfds, fd_set *readfds, fd_set *writefds,
           fd_set *exceptfds, struct timeval *timeout);

/*
参数：
	nfds：		监控的文件描述符集里最大文件描述符加1，因为此参数会告诉内核检测前多少个文件描述符的状态
	readfds：	监控有读数据到达文件描述符集合，传入传出参数
	writefds：	监控写数据到达文件描述符集合，传入传出参数
	exceptfds：	监控异常发生到达文件描述符集合，如带外数据到达异常，传入传出参数
	timeout：	定时阻塞监控时间
				1、NULL，永远阻塞等待
				2、设置timeval，等待固定时间
				3、设置timeval里的时间均为0，检查描述字后立刻返回，轮询
返回值：
	成功：返回三个返回描述符集中包含的文件描述符的数量(即，在readfds、writefds和exceptfds中设置的总位数)，如果超时在任何有趣的事情发生之前过期，该数量可能为零。
	失败：错误返回-1，设置errno
*/
// 文件描述符集操作函数
void FD_CLR(int fd, fd_set *set);
int  FD_ISSET(int fd, fd_set *set);
void FD_SET(int fd, fd_set *set);
void FD_ZERO(fd_set *set);

struct timeval {
    long    tv_sec;         /* seconds */
    long    tv_usec;        /* microseconds */
};
```

应用案例：

```c
#include <stdio.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <string.h>
#include <unistd.h>
#include <sys/select.h>
#include "wrap.h"

#define MAXSIZE 8192
#define SERV_PORT 8888

int main(void)
{
        int i, maxi, nready, n;
        int lfd, cfd, sfd, maxfd;
        int client[FD_SETSIZE];     // 自定义数组client，防止遍历1024个文件描述符，FD_SETSIZE默认为1024
        char buf[MAXSIZE] = {0};

        struct sockaddr_in serv_addr, clie_addr;
        socklen_t clie_addr_len;
        fd_set rset, allset;      // rset 读事件文件描述符集合 allset 用于暂存

        char clientip[256];


        lfd = Socket(AF_INET, SOCK_STREAM, 0);

        bzero(&serv_addr, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERV_PORT);
        serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);  // 指定本地任意IP
        //inet_pton(AF_INET, "192.168.10.100", &serv_addr.sin_addr.s_addr);

        Bind(lfd, (const struct sockaddr *)&serv_addr, (socklen_t)sizeof(serv_addr));
        Listen(lfd, 128); // 设置同一时刻连接服务器的上限，操作系统运行最大监听数为128

        maxfd = lfd;  // 刚开始lfd即为最大文件描述符

        maxi = -1;    // 用-1初始化client[]
        for(i = 0; i < FD_SETSIZE; i++)
                client[i] = -1;

        FD_ZERO(&allset);   // 构造select监控文件描述符集
        FD_SET(lfd, &allset);

        printf("Accepting client connect ...\n");

        while(1)
        {
                rset = allset;  // 每次循环时都重新设置select监控信号集，因为select函数会修改其值
                nready = select(maxfd+1, &rset, NULL, NULL, NULL);
                if(nready < 0)
                {
                        perror("select error");
                        exit(1);
                }

                // 如果有新的客户端连接请求
                if(FD_ISSET(lfd, &rset))
                {
                  clie_addr_len = sizeof(clie_addr);
                  cfd = Accept(lfd, (struct sockaddr *)&clie_addr, &clie_addr_len); // 阻塞监听客户端连接请求
                  printf("rcv from %s at port %d\n",
                                inet_ntop(AF_INET, &clie_addr.sin_addr.s_addr, clientip, sizeof(clientip)),
                                ntohs(clie_addr.sin_port));

                  // 找到client[]中没有用的位置
                  // 保存accept返回的文件描述符到client[]
                  for(i = 0; i < FD_SETSIZE; i++)
                  {
                    if(client[i] < 0)
                    {
                      client[i] = cfd;
                      printf("add a new client[%d] = %d\n", i, cfd);
                      break;
                    }
                  }

                  // 达到select能监控的文件个数上限 1024
                  if(i == FD_SETSIZE)
                  {
                    fputs("too many clients\n", stderr);
                  }

                  // 向监控文件描述符集合allset添加新的文件描述符cfd
                  FD_SET(cfd, &allset);
                  if(cfd > maxfd)
                          maxfd = cfd;

                  // 保证maxi存的总是client[]最后一个元素的下标
                  if(i > maxi)
                          maxi = i;

                  if(--nready == 0)
                          continue;

                }

                // 检测那个client有数据就绪
                for(i = 0; i <= maxi; i++)
                {
                  if((sfd = client[i]) < 0)
                          continue;

                  if(FD_ISSET(sfd, &rset))
                  {
                    printf("Ready to read client data.\n");

                    // 当client关闭连接时，服务器端也关闭对应连接
                    if((n = Read(sfd, buf, sizeof(buf))) == 0)
                    {
                      Close(sfd);
                      // 解除select对此文件描述符的监控
                      FD_CLR(sfd, &allset);
                      client[i] = -1;
                    }
                    else if(n > 0)
                    {
                      for(int j = 0; j < n; j++)
                              buf[j] = toupper(buf[j]);
                      sleep(10);
                      Write(sfd, buf, n);
                      Write(STDOUT_FILENO, buf, n);
                    }
                    if(--nready == 0)
                            break;    // 跳出for，但还在while
                  }
                }
        }
        Close(lfd);
        return 0;
}
```

## poll

poll是select的升级版。特点：

1. poll可以突破1024个打开文件描述符的上限。
2. 监听、返回集合是分离的。
3. 搜索范围变小。

ulimit - a 命令可以查看允许打开的文件描述符个数。

```shell
ulimit -a
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 13312
max locked memory       (kbytes, -l) 65536
max memory size         (kbytes, -m) unlimited
open files                      (-n) 1024
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 8192
cpu time               (seconds, -t) unlimited
max user processes              (-u) 13312
virtual memory          (kbytes, -v) unlimited
file locks 
```

open files 是允许打开的文件描述符个数。

使用命令cat查看一个进程可以打开的socket描述符上线，这个是根据计算机硬件条件能打开文件描述符的最大值。

```shell
cat /proc/sys/fs/file-max
```

如果有需要，可以通过修改配置文件的方式修改该上限值。修改完重启或者注销用户即可生效。

```shell
sudo vim /etc/security/limits.conf
在文件尾部写入以下配置，soft软限制，hard硬限制。
*               soft    nofile          3000
*               hard    nofile          10000
```

应用案例：

```c
#include <poll.h>
int poll(struct pollfd *fds, nfds_t nfds, int timeout);
/*
参数：
	fds：监控数组的首地址
	nfds：监控数组中需要监控的文件描述符数量
	timeout：-1：阻塞等待；0：立即返回；>0：等待指定时长。
返回值：
	成功：返回满足条件的文件描述符个数
	失败：返回-1，设置errno
*/
struct pollfd {
    int   fd;         /* file descriptor 要监听的文件描述符*/
    short events;     /* requested events 监听该文件描述符的什么事件 POLLIN\POLLOUT\POLLERR*/
    short revents;    /* returned events 满足条件返回的事件*/
};
/*
POLLIN		普通或带外优先数据可读，即POLLRDNORM | POLLRDBAND
*/
```

应用案例：

```c
#include <stdio.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <errno.h>
#include <sys/types.h>          /* See NOTES */
#include <sys/socket.h>
#include "wrap.h"

#define MAXSIZE 1024
#define SERV_PORT 8888
#define MAXLINE 80
#define OPEN_MAX 3000

int main(void)
{
        ssize_t n;
        int i, maxi;
        int nready;             // 接收poll返回值，记录满足监听事件的fd个数
        int lfd, cfd, sfd;
        char buf[MAXLINE] = {0};

        struct sockaddr_in serv_addr, clie_addr;
        socklen_t clie_addr_len;
        struct pollfd client[OPEN_MAX]; // poll数组

        char clientip[INET_ADDRSTRLEN]; // 暂存连接的客户端ip


        lfd = Socket(AF_INET, SOCK_STREAM, 0);

        // 设置端口复用
        int opt = 1;
        setsockopt(lfd, SOL_SOCKET,  SO_REUSEADDR, &opt, sizeof(opt));

        bzero(&serv_addr, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERV_PORT);
        serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);  // 指定本地任意IP
        //inet_pton(AF_INET, "192.168.10.100", &serv_addr.sin_addr.s_addr);

        Bind(lfd, (const struct sockaddr *)&serv_addr, (socklen_t)sizeof(serv_addr));
        Listen(lfd, 128); // 设置同一时刻连接服务器的上限，操作系统运行最大监听数为128

        // 要监听的第一个文件描述符，存入client[0]
        client[0].fd = lfd;
        // lfd 监听普通读事件
        client[0].events = POLLIN;

        //用-1初始化client[]里面剩下的元素 0也是文件描述符，不能用
        for(i = 1; i < OPEN_MAX; i++)
                client[i].fd = -1;

        // client[]数组中有效元素的最大元素下标
        maxi = 0;

        printf("Accept to connecting...\n");
        for(;;)
        {
                // 阻塞监听是否有客户端连接请求
                nready = poll(client, maxi+1, -1);

                // lfd有读事件就绪
                if(client[0].revents & POLLIN)
                {
                        clie_addr_len = sizeof(clie_addr);
                        cfd = Accept(lfd, (struct sockaddr *)&clie_addr, &clie_addr_len); // 阻塞监听客户端连接请求
                        printf("rcv from %s at port %d\n",
                                        inet_ntop(AF_INET, &clie_addr.sin_addr.s_addr, clientip, sizeof(clientip)),
                                        ntohs(clie_addr.sin_port));
                        for(i = 1; i < OPEN_MAX; i++)
                        {
                                if(client[i].fd < 0)
                                {

                                        // 找到client[]中空闲的位置，存放accept返回的cfd
                                        client[i].fd = cfd;
                                        break;
                                }
                        }

                        // 达到最大客户端书
                        if(i == OPEN_MAX)
                        {
                                perror("too many clients");
                                exit(1);
                        }

                        // 设置刚刚返回的cfd，监控读事件
                        client[i].events = POLLIN;

                        // 更新client[]中最大元素的下标
                        if(i > maxi)
                                maxi = i;

                        // 没有更多的就绪事件时，继续返回poll阻塞
                        if(--nready == 0)
                                continue;
                }

                // 前面的if没有满足，说明没有lfd满足，则检测client[]看是哪个cfd就绪
                for(i = 0; i <= maxi; i++)
                {
                        if((sfd = client[i].fd) < 0)
                                continue;

                        if(client[i].revents & POLLIN)
                        {
                                printf("Ready to read client data.\n");

                                // 当client关闭连接时，服务器端也关闭对应连接
                                if((n = Read(sfd, buf, sizeof(buf))) == 0)
                                {
                                        // 说明客户端先关闭连接
                                        printf("client[%d] closed connection\n", i);
                                        Close(sfd);
                                        // 解除poll对此文件描述符的监控
                                        client[i].fd = -1;
                                }
                                else if(n > 0)
                                {
                                        for(int j = 0; j < n; j++)
                                                buf[j] = toupper(buf[j]);
                                        sleep(10);
                                        Write(sfd, buf, n);
                                        Write(STDOUT_FILENO, buf, n);
                                }
                                else
                                {
                                        // connection reset by client
                                        // 收到RST标志
                                        if(errno == ECONNRESET)
                                        {
                                                printf("client[%d] aborted connection\n", i);
                                                Close(sfd);
                                                client[i].fd = -1;
                                        }
                                        else
                                        {
                                                perror("read error");
                                                exit(1);
                                        }
                                }
                                if(--nready == 0)
                                        break;    // 跳出for，但还在while
                        }

                }
        }
        Close(lfd);
        return 0;
}
```

## epoll

epoll是Linux下多路复用IO接口select/poll的增强版本，它能显著提高程序在大量并发连接中只有少量活跃的情况下的系统CPU利用率，因为它会复用文件描述符集合来传递结果而不用迫使开发者每次等待事件之前都必须重新准备要被侦听的文件描述符集合，另外一点原因就是获取事件的时候，它无需遍历整个被侦听的描述符集合，只要遍历那些被内核IO事件异步唤醒而加入Ready队列的描述符集合即可。

epoll是Linux大规模并发网络程序中的热门首选模型。

epoll除了提供select/poll那种IO事件的电平触发（Level Triggered）外，还提供了边沿触发（Edge Triggered），这就使得用户空间程序有可能缓存IO状态，减少epoll_wait/epoll_pwait的调用，提高应用程序效率。

### 基础API

1、创建一个epoll句柄，参数size用来告诉内核监听的文件描述符的个数，跟内存大小有关。

> 平衡二叉树：左子树和右子树的高度差小于1的二叉树。
>
> 平衡二叉树查找最快的方法：二分法。

```c
#include <sys/epoll.h>
int epoll_create(int size);  
/* 
	size:监听的文件描述符的个数，是给Linux内核的一个参考，实际监听的个数可以大于它。实际上用于一个红黑树。
	返回值：一个文件描述符epfd，这个epfd文件描述符指向一个红黑树（效率较高的平衡二叉树）的树根
*/
```

2、控制某个epoll监听的文件描述符上的事件：注册、修改、删除。

```c
#include <sys/epoll.h>
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
/*
	epfd：为epoll_create的句柄
	op：表示动作，用3个宏来表示：
    	EPOLL_CTL_ADD (注册新的fd到epfd)(添加一个红黑树的节点)，
    	EPOLL_CTL_MOD (修改已经注册的fd的监听事件)(修改一个红黑树的节点)，
    	EPOLL_CTL_DEL (从epfd删除一个fd)(删除一个红黑树的节点)；
    fd：对哪个文件描述符进行注册、修改、删除。
	event：告诉内核要监听的事件，传入参数
*/

typedef union epoll_data {
    void        *ptr;
    int          fd;
    uint32_t     u32;
    uint64_t     u64;
} epoll_data_t;

struct epoll_event {
    uint32_t     events;      /* Epoll events */
    epoll_data_t data;        /* User data variable */
};
/*
	events：EPOLLIN\EPOLLOUT\EPOLLERR...
*/
```

3、等待所监控文件描述符上有事件的产生，类似于select()调用

```c
#include <sys/epoll.h>
int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
/*
参数：
	epfd：为epoll_create的句柄
	events：用来存内核得到事件的集合，数组，传出参数
	maxevents：告诉内核这个events多大，这个maxevents的值不能大于epoll_create()时的size，数组容量
	timeout：超时时间
		-1：阻塞
		0：立即返回，非阻塞
		>0：指定阻塞多少毫秒
返回值：
	成功：返回有多少文件描述符就绪
	时间到时：返回0
	失败：返回-1
*/
```

### 应用案例：

```c
#include <stdio.h>
#include <arpa/inet.h>
#include <ctype.h>
#include <string.h>
#include <unistd.h>
#include <sys/epoll.h>
#include <errno.h>
#include <sys/types.h>          /* See NOTES */
#include <sys/socket.h>
#include "wrap.h"

#define SERV_PORT 8888
#define MAXLINE 8192
#define OPEN_MAX 3000

int main(void)
{
        ssize_t efd, res, nready;
        int i, n, num;
        int lfd, cfd, sfd;
        char buf[MAXLINE] = {0};

        struct sockaddr_in serv_addr, clie_addr;
        socklen_t clie_addr_len;
        struct epoll_event tep, ep[OPEN_MAX];   // tep：epoll_ctl参数； ep[]：epoll_wait参数
        char clientip[INET_ADDRSTRLEN]; // 暂存连接的客户端ip


        lfd = Socket(AF_INET, SOCK_STREAM, 0);

        // 设置端口复用
        int opt = 1;
        setsockopt(lfd, SOL_SOCKET,  SO_REUSEADDR, &opt, sizeof(opt));

        bzero(&serv_addr, sizeof(serv_addr));
        serv_addr.sin_family = AF_INET;
        serv_addr.sin_port = htons(SERV_PORT);
        serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);  // 指定本地任意IP
        //inet_pton(AF_INET, "192.168.10.100", &serv_addr.sin_addr.s_addr);

        Bind(lfd, (const struct sockaddr *)&serv_addr, (socklen_t)sizeof(serv_addr));
        Listen(lfd, 128); // 设置同一时刻连接服务器的上限，操作系统运行最大监听数为128

        efd = epoll_create(OPEN_MAX);   // 创建epoll模型，efd指向红黑树根节点
        if(efd == -1)
        {
                perror("epoll_create error");
                exit(1);
        }

        // 指定lfd的监听事件为读
        tep.events = EPOLLIN;
        tep.data.fd = lfd;

        // 将lfd及对应的结构体设置到树上，efd可找到该树
        res = epoll_ctl(efd, EPOLL_CTL_ADD, lfd, &tep);
        if(res == -1)
        {
                perror("epoll_ctl error");
                exit(1);
        }

        printf("Accept to connecting...\n");
        for(;;)
        {
                // epoll为server阻塞监听事件，ep为struct
                // epoll_event类型的数组，OPEN_MAX为数组容量，-1表示阻塞等待
                nready = epoll_wait(efd, ep, OPEN_MAX, -1);
                if(nready == -1)
                {
                        perror("epoll_wait error");
                        exit(1);
                }

                for(i = 0; i < nready; i++)
                {
                        // 如果不是读事件，跳过后面，继续下一次循环
                        if(!(ep[i].events & EPOLLIN))
                                continue;

                        // 判断满足事件的fd是否为lfd
                        if(ep[i].data.fd == lfd)
                        {

                                clie_addr_len = sizeof(clie_addr);
                                cfd = Accept(lfd, (struct sockaddr *)&clie_addr, &clie_addr_len); // 阻塞监听客户端连接请求
                                printf("rcv from %s at port %d\n",
                                                inet_ntop(AF_INET, &clie_addr.sin_addr.s_addr, clientip, sizeof(clientip)),
                                                ntohs(clie_addr.sin_port));
                                printf("cfd[%d] --- client[%d]\n", cfd, ++num);

                                // 将新连接的客户端加入到epoll的读事件监听
                                tep.events = EPOLLIN;
                                tep.data.fd = cfd;
                                res = epoll_ctl(efd, EPOLL_CTL_ADD, cfd, &tep);
                                if(res == -1)
                                {
                                        perror("epoll_ctl error");
                                        exit(1);
                                }
                        }
                        else // 不是lfd
                        {
                                sfd = ep[i].data.fd;
                                n = Read(sfd, buf, MAXLINE);
                                // 读到0，说明客户端关闭连接
                                // 则需要将该文件描述符从红黑树删除
                                if(n == 0)
                                {
                                        res = epoll_ctl(efd, EPOLL_CTL_DEL, sfd, NULL);
                                        if(res == -1)
                                        {
                                                perror("epoll_ctl error");
                                                exit(1);
                                        }
                                        Close(sfd); // 关闭与该客户端的连接
                                        printf("client[%d] closed connection\n", sfd);
                                }
                                else if(n < 0)
                                {
                                        perror("read n < 0 error:");
                                        res = epoll_ctl(efd, EPOLL_CTL_DEL, sfd, NULL);
                                        if(res == -1)
                                        {
                                                perror("epoll_ctl error");
                                                exit(1);
                                        }
                                        Close(sfd); // 关闭与该客户端的连接
                                }
                                else
                                {
                                        for(i = 0; i < n; i++)
                                        {
                                                buf[i] = toupper(buf[i]);
                                        }
                                        Write(STDOUT_FILENO, buf, n);
                                        Write(sfd, buf, n);
                                }
                        }
                }


        }
        Close(lfd);
        return 0;
}
```

### 水平触发(epoll LT)和边缘触发(epoll ET)

水平触发(epoll LT)：只要文件描述符的读写缓冲区里还有数据没被读走，就会一直触发，也就是再次调用epoll_wait时会再次立刻返回，直到读写缓冲区里的数据被完全读走。epoll默认就是这种模式。

边缘触发(epoll ET)：只当文件描述符的读写缓冲区的来了一次数据，才会触发一次，再次调用epoll_wait时不会立刻返回，即使没有把缓冲区里的数据完全读走，直到文件描述符的读写缓冲区再一次来了新数据才会触发返回。

```c
#include <stdio.h>
#include <stdlib.h>
#include <sys/epoll.h>
#include <errno.h>
#include <unistd.h>

#define MAXLINE 10

int main(void)
{
  int efd, i;
  int pfd[2];
  pid_t pid;
  char buf[MAXLINE];
  char ch = 'a';

  pipe(pfd);
  pid = fork();

  // 子进程 写
  if(pid == 0)
  {
    close(pfd[0]);
    while(1)
    {
      // aaaa\n
      for(i = 0; i < MAXLINE/2; i++)
      {
        buf[i] = ch;
      }
      buf[i - 1] = '\n';
      ch++;
      // bbbb\n
      for(; i < MAXLINE; i++)
      {
        buf[i] = ch;
      }
      buf[i - 1] = '\n';
      ch++;
      // aaaa\nbbbb\n
      write(pfd[1], buf, sizeof(buf));
      sleep(1);
      write(STDOUT_FILENO, "sleep 1\n", 8);
      sleep(1);
      write(STDOUT_FILENO, "sleep 2\n", 8);
      sleep(1);
      write(STDOUT_FILENO, "sleep 3\n", 8);
      sleep(1);
      write(STDOUT_FILENO, "sleep 4\n", 8);
      sleep(1);
      write(STDOUT_FILENO, "sleep 5\n", 8);
    }
    close(pfd[1]);
  }
  // 父进程 读
  else if(pid > 0)
  {
    struct epoll_event event;       // epoll_ctl 设置的最后一个参数
    struct epoll_event revent[10];  // epoll_wait 就绪返回数组
    int ret, len;

    close(pfd[1]);
    efd = epoll_create(10);          // 创建可以容纳10个节点的红黑树，返回红黑树树根

    event.events = EPOLLIN | EPOLLET; // ET边缘触发
    // event.events = EPOLLIN;        // LT水平触发
    event.data.fd = pfd[0];
    ret = epoll_ctl(efd, EPOLL_CTL_ADD, pfd[0], & event);
    if(ret == -1)
    {
      perror("epoll_ctl error");
      exit(1);
    }

    while(1)
    {
      write(STDOUT_FILENO, "epoll_wait...\n", 14);
      ret = epoll_wait(efd, revent, MAXLINE, -1); // -1阻塞
      printf("ret %d\n", ret);
      if(revent[0].data.fd == pfd[0])
      {
        len = read(pfd[0], buf, MAXLINE/2);
        write(STDOUT_FILENO, buf, len);
      }
    }
    close(pfd[0]);
    close(efd);
  }
  else
  {
    perror("fork error");
    exit(1);
  }

  return 0;

}
```

### epoll非阻塞IO

这是非常典型的epoll的应用，常用模式这种模式可以减少epoll_wait的调用，提高程序的效率。因为是非阻塞IO，所有需要对用fcntl()对cfd套接字进行非阻塞设置。

```c
// client.c
#include <stdio.h>
#include <stdlib.h>
#include <sys/epoll.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>          /* See NOTES */
#include <sys/socket.h>
#include <arpa/inet.h>
#include <strings.h>

#define MAXLINE 10
#define SERV_PORT 8888
int main(void)
{
        struct sockaddr_in servaddr;
        char buf[MAXLINE];
        char ch = 'a';
        int sfd, i;

        sfd = socket(AF_INET, SOCK_STREAM,0);

        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        inet_pton(AF_INET, "127.0.0.1", &servaddr.sin_addr);
        servaddr.sin_port = htons(SERV_PORT);

        connect(sfd, (struct sockaddr *)&servaddr, sizeof(servaddr));

        while(1)
        {
                // aaaa\n
                for(i = 0; i < MAXLINE/2; i++)
                {
                        buf[i] = ch;
                }
                buf[i - 1] = '\n';
                ch++;
                // bbbb\n
                for(; i < MAXLINE; i++)
                {
                        buf[i] = ch;
                }
                buf[i - 1] = '\n';
                ch++;
                // aaaa\nbbbb\n
                write(sfd, buf, sizeof(buf));
                sleep(1);
                write(STDOUT_FILENO, "sleep 1\n", 8);
                sleep(1);
                write(STDOUT_FILENO, "sleep 2\n", 8);
                sleep(1);
                write(STDOUT_FILENO, "sleep 3\n", 8);
                sleep(1);
                write(STDOUT_FILENO, "sleep 4\n", 8);
                sleep(1);
                write(STDOUT_FILENO, "sleep 5\n", 8);

        }
        close(sfd);
        return 0;
}
```

```c
// server.c
#include <stdio.h>
#include <stdlib.h>
#include <sys/epoll.h>
#include <errno.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <strings.h>
#include <fcntl.h>

#define MAXLINE 10
#define SERV_PORT 8888

int main(void)
{
  int efd;
  int lfd, cfd;
  char buf[MAXLINE];
  char ipstr[INET_ADDRSTRLEN];

  struct sockaddr_in servaddr, cliaddr;
  socklen_t cliaddr_len;

  lfd = socket(AF_INET, SOCK_STREAM, 0);

  bzero(&servaddr, sizeof(servaddr));
  servaddr.sin_family = AF_INET;
  servaddr.sin_port = htons(SERV_PORT);
  servaddr.sin_addr.s_addr = htonl(INADDR_ANY);

  bind(lfd, (struct sockaddr *)&servaddr, sizeof(servaddr));

  listen(lfd, 128);

  struct epoll_event ev;
  struct epoll_event rev[10];
  int res, len;

  efd = epoll_create(10);
  ev.events = EPOLLIN | EPOLLET;  // ET边沿触发
  //ev.events = EPOLLIN;         // LT水平触发

  printf("Accepting connections...\n");

  cliaddr_len = sizeof(cliaddr);
  cfd = accept(lfd, (struct sockaddr *)&cliaddr, &cliaddr_len);
  printf("received from %s at port %d\n",
                  inet_ntop(AF_INET, &cliaddr.sin_addr, ipstr, sizeof(ipstr)),
                  ntohs(cliaddr.sin_port));

  // 修改cfd为非阻塞读
  int flag = fcntl(cfd, F_GETFL);
  flag |= O_NONBLOCK;
  fcntl(cfd, F_SETFL, flag);

  ev.data.fd = cfd;
  epoll_ctl(efd, EPOLL_CTL_ADD, cfd, &ev);

  while(1)
  {
    printf("epoll_wait begin\n");
    res = epoll_wait(efd, rev, 10, -1);
    printf("epoll_wait end\n");
    printf("res %d\n", res);

    if(rev[0].data.fd == cfd)
    {
      // 非阻塞读，轮询
      while((len = read(cfd, buf, MAXLINE/2)) > 0)
        write(STDOUT_FILENO, buf, len);
    }
  }

  return 0;

}
```
