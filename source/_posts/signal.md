---
title: 信号
tags:
  - Linux
  - 信号
categories:
  - Linux
date: 2021-07-05 13:57:48
---
# 信号

## 1、信号的概念

### 共性

1. 简单。
2. 不能携带大量信息。
3. 满足某个特设条件才能发送。

### 机制

A给B发送信号，B收到信号前执行自己的代码，收到信号好后，不管执行到程序的什么位置，都要暂停运行， 去处理信号，处理完毕再继续运行。与硬件中断类似，但信号是软件层面上实现的终端，常称为“软中断”。

> **每个进程收到的所有信号，都是由内核负责发送的，内核处理。**

### 阻塞信号集（信号屏蔽字）

将某些信号加入集合，对他们设置屏蔽，当屏蔽x信号后，再收到该信号，该信号的处理将推后（解除屏蔽后），`未决信号集`的对应信号位置将不再立刻翻转，常为1。

### 未决信号集

1. 信号产生，未决信号集中描述该信号的位立刻翻转为1，表示信号处于未决状态。当信号被处理，对应位翻转回0。这一时刻“光速”。
2. 信号产生后由于某些原因（主要是阻塞）不能抵达。这类信号的集合称之为未决信号集。在屏蔽解除前，信号一直处于未决状态。

### 信号的编号

```shell
cyh@cyh-virtual-machine:~$kill -l
 1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL       5) SIGTRAP
 6) SIGABRT      7) SIGBUS       8) SIGFPE       9) SIGKILL     10) SIGUSR1
11) SIGSEGV     12) SIGUSR2     13) SIGPIPE     14) SIGALRM     15) SIGTERM
16) SIGSTKFLT   17) SIGCHLD     18) SIGCONT     19) SIGSTOP     20) SIGTSTP
21) SIGTTIN     22) SIGTTOU     23) SIGURG      24) SIGXCPU     25) SIGXFSZ
26) SIGVTALRM   27) SIGPROF     28) SIGWINCH    29) SIGIO       30) SIGPWR
31) SIGSYS      34) SIGRTMIN    35) SIGRTMIN+1  36) SIGRTMIN+2  37) SIGRTMIN+3
38) SIGRTMIN+4  39) SIGRTMIN+5  40) SIGRTMIN+6  41) SIGRTMIN+7  42) SIGRTMIN+8
43) SIGRTMIN+9  44) SIGRTMIN+10 45) SIGRTMIN+11 46) SIGRTMIN+12 47) SIGRTMIN+13
48) SIGRTMIN+14 49) SIGRTMIN+15 50) SIGRTMAX-14 51) SIGRTMAX-13 52) SIGRTMAX-12
53) SIGRTMAX-11 54) SIGRTMAX-10 55) SIGRTMAX-9  56) SIGRTMAX-8  57) SIGRTMAX-7
58) SIGRTMAX-6  59) SIGRTMAX-5  60) SIGRTMAX-4  61) SIGRTMAX-3  62) SIGRTMAX-2
63) SIGRTMAX-1  64) SIGRTMAX
```

- 1-31为普通信号（常规信号）。
  - 常用2、3、7、8、9、10、11、12、13、14、15、17、19、20号信号

- 34-64为实时信号，一般是在嵌入式驱动开发中才用得到，应用层开发一般不用。

可通过`man 7 signal`查看详细说明

```c
Signal      Standard   Action   Comment
────────────────────────────────────────────────────────────────────────
SIGABRT      P1990      Core    Abort signal from abort(3)
SIGALRM      P1990      Term    Timer signal from alarm(2)
SIGBUS       P2001      Core    Bus error (bad memory access)
SIGCHLD      P1990      Ign     Child stopped or terminated
SIGCLD         -        Ign     A synonym for SIGCHLD
SIGCONT      P1990      Cont    Continue if stopped
SIGEMT         -        Term    Emulator trap
SIGFPE       P1990      Core    Floating-point exception
SIGHUP       P1990      Term    Hangup detected on controlling terminal
                               or death of controlling process
SIGILL       P1990      Core    Illegal Instruction
SIGINFO        -                A synonym for SIGPWR
SIGINT       P1990      Term    Interrupt from keyboard
SIGIO          -        Term    I/O now possible (4.2BSD)
SIGIOT         -        Core    IOT trap. A synonym for SIGABRT
SIGKILL      P1990      Term    Kill signal
SIGLOST        -        Term    File lock lost (unused)
SIGPIPE      P1990      Term    Broken pipe: write to pipe with no
                               readers; see pipe(7)
SIGPOLL      P2001      Term    Pollable event (Sys V).
                               Synonym for SIGIO
SIGPROF      P2001      Term    Profiling timer expired
SIGPWR         -        Term    Power failure (System V)
SIGQUIT      P1990      Core    Quit from keyboard
SIGSEGV      P1990      Core    Invalid memory reference
SIGSTKFLT      -        Term    Stack fault on coprocessor (unused)
SIGSTOP      P1990      Stop    Stop process
SIGTSTP      P1990      Stop    Stop typed at terminal
SIGSYS       P2001      Core    Bad system call (SVr4);
                               see also seccomp(2)
SIGTERM      P1990      Term    Termination signal

SIGTRAP      P2001      Core    Trace/breakpoint trap
SIGTTIN      P1990      Stop    Terminal input for background process
SIGTTOU      P1990      Stop    Terminal output for background process
SIGUNUSED      -        Core    Synonymous with SIGSYS
SIGURG       P2001      Ign     Urgent condition on socket (4.2BSD)
SIGUSR1      P1990      Term    User-defined signal 1
SIGUSR2      P1990      Term    User-defined signal 2
SIGVTALRM    P2001      Term    Virtual alarm clock (4.2BSD)
SIGXCPU      P2001      Core    CPU time limit exceeded (4.2BSD);
                               see setrlimit(2)
SIGXFSZ      P2001      Core    File size limit exceeded (4.2BSD);
                               see setrlimit(2)
SIGWINCH       -        Ign     Window resize signal (4.3BSD, Sun)

The signals SIGKILL and SIGSTOP cannot be caught, blocked, or ignored.
//9)SIGKILL、19)SIGSTOP信号，不允许忽略或者捕获，只能执行默认动作。甚至不能将其阻塞。
```

```
Signal        x86/ARM     Alpha/   MIPS   PARISC   Notes
           most others   SPARC
─────────────────────────────────────────────────────────────────
SIGHUP           1           1       1       1
SIGINT           2           2       2       2
SIGQUIT          3           3       3       3
SIGILL           4           4       4       4
SIGTRAP          5           5       5       5
SIGABRT          6           6       6       6
SIGIOT           6           6       6       6
SIGBUS           7          10      10      10
SIGEMT           -           7       7      -
SIGFPE           8           8       8       8
SIGKILL          9           9       9       9
SIGUSR1         10          30      16      16
SIGSEGV         11          11      11      11
SIGUSR2         12          31      17      17
SIGPIPE         13          13      13      13
SIGALRM         14          14      14      14
SIGTERM         15          15      15      15
SIGSTKFLT       16          -       -        7
SIGCHLD         17          20      18      18
SIGCLD           -          -       18      -
SIGCONT         18          19      25      26
SIGSTOP         19          17      23      24

SIGTSTP         20          18      24      25
SIGTTIN         21          21      26      27
SIGTTOU         22          22      27      28
SIGURG          23          16      21      29
SIGXCPU         24          24      30      12
SIGXFSZ         25          25      31      30
SIGVTALRM       26          26      28      20
SIGPROF         27          27      29      21
SIGWINCH        28          28      20      23
SIGIO           29          23      22      22
SIGPOLL                                            Same as SIGIO
SIGPWR          30         29/-     19      19
SIGINFO          -         29/-     -       -
SIGLOST          -         -/29     -       -
SIGSYS          31          12      12      31
SIGUNUSED       31          -       -       31
```

### 默认动作

- Term：终止进程，如kill。
- Ign：忽略信号（默认即时对该信号忽略操作），如子进程退出时通知父进程的“收尸”信号。
- Core：终止进程，生成Core文件。（查验进程死亡原因，用于gdb调试）
- Stop：停止（暂停）进程。
- Cont：继续运行进程

> 注意：只有每个信号所对应的事件发生了，该信号才会被递送（但不一定递达），不应该乱发信号！

### 信号的处理方式

1. 执行默认动作
2. 忽略（丢弃）
3. 捕捉（调用用户处理函数）

### 信号4要素

1. 编号
2. 名称
3. 事件
4. 默认处理动作

### 产生信号5种方式

1. 按键产生： 2) SIGINT `Ctrl+c `、20) SIGTSTP `Ctrl+z`、3) SIGQUIT `Ctrl+\`
2. 系统调用：`kill()`、`raise()` 、`abort()`
3. 软件条件产生：定时器alarm
4. 硬件异常产生：非法访问内存（段错误）、除0（浮点数例外）、内存对齐出错（总线错误）
5. 命令产生：kill - 9

## 2、信号产生函数

### kill()

```c
#include <sys/types.h>
#include <signal.h>
int kill(pid_t pid, int sig);
```

参数：

- pid：进程id

  pid >0：发送信号给指定进程。

  pid=0：发送信号给 与 调用kill()函数进程属于同一进程组的所有进程。

  pid<0：取pid的绝对值|pid|发送给对应进程组。

  pid=-1：发送给进程所有权限发送的系统中所有进程。

  进程组：每个进程都属于一个进程组，进程组是一个或者多个进程的集合，相互关联，共同完成一个用户概念的任务，每个进程组都有一个进程组长，默认进程组ID与进程组长ID相同。

  权限保护：super用户（root）可以发送信号给任何用户，普通用户不能向系统用户发送 信号，在普通用户中，使用`kill -9 (root用户的pid)`是不能成功的，同时，普通用户也不能给其他普通用户发送信号，终止其进程。只能向自己创建的进程发送信号。普通用户基本原则：发送者实际或有效用户ID == 接收者实际或有效用户ID。

- sig：信号类型

返回值：成功返回0，失败返回-1。

```shell
$ ps ajx
   PPID     PID    PGID     SID TTY        TPGID STAT   UID   TIME COMMAND
      0       1       1       1 ?             -1 Ss       0   0:08 /sbin/init splash
      0       2       0       0 ?             -1 S        0   0:00 [kthreadd]
      2       3       0       0 ?             -1 I<       0   0:00 [rcu_gp]
```

父进程ID(PPID)，进程ID(PID )，进程组ID(PGID)，会话组ID(SID)。

### raise()和abort()

raise函数：给当前进程发送指定信号（自发自收）。raise(signo) == kill(getpid(), signo);

​		int raise(int sig); 成功返回0，失败返回非0值。

abort函数：给自己发送异常终止信号 6) SIGABRT 信号，终止并产生core文件。

​		void abort(void); 

### alaram()

设置定时器，在指定seconds后，内核会给当前进程发送 14) SIGALRM 信号。进程收到该信号，默认终止进程。

**注意：每个进程有且只有一个定时器。**

```c
#include <unistd.h>
unsigned int alarm(unsigned int seconds); // 返回0或者上一次定时剩余的秒数，不会失败。
```

常用alram(0)来取消定时器。

**与进程状态无关的自然定时法！！**无论进程处于就绪、运行、挂起（阻塞、暂停）、终止、僵尸...alarm都计时而不会被打断。

```c
// 统计1秒内计算机能数多少个数。
#include <stdio.h>
#include <unistd.h>

int main(void)
{
  alarm(1);
  for(int i = 0; ; i++)
  {
    printf("%d \n", i);
  }
  return 0;
}
```

```shell
$ time ./a.out  > cnt    //应用程序前加time可以统计一个程序的运行时间， > cnt 表示输出重定向到文件cnt 
...
real    0m1.082s
user    0m0.022s	// 程序在用户空间的时间
sys     0m0.986s	// 程序在内核空间的时间
```

### setitimer()

设置定时器，可替代alarm函数。精度微妙us。可以实现周期性定时。

```c
#include <sys/time.h>
struct itimerval {
    struct timeval it_interval; /* Interval for periodic timer 两次定时的间隔时间*/
    struct timeval it_value;    /* Time until next expiration 定时的时长*/
};
struct timeval {
    time_t      tv_sec;         /* seconds */
    suseconds_t tv_usec;        /* microseconds */
};
int getitimer(int which, struct itimerval *curr_value);
int setitimer(int which, const struct itimerval *new_value, struct itimerval *old_value);
```

参数：

- which：指定定时方式
  1. 自然定时：ITIMER ==> 14) SIGLARM 			                                         计算自然时间
  2. 虚拟空间计时（用户空间）：ITIMER_VIRTUAL ==> 26) SIGVTALRM  只计算进程占用cpu的时间
  3. 运行时计时（用户+内核）：ITIMER_PROF ==> 27) SIGPROF              计算占用cpu和执行系统调用的时间

- new_value：定时的时间
- old_value：上次定时剩余的时间

```c
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>

unsigned int my_alarm(unsigned int sec)
{
  struct itimerval it, lastit;

  it.it_value.tv_sec = sec;
  it.it_value.tv_usec = 0;
  it.it_interval.tv_sec = 0;
  it.it_interval.tv_usec = 0;

  int ret = setitimer(ITIMER_REAL, &it, &lastit);
  if(ret == -1)
  {
    perror("setitimer");
    exit(1);
  }

  return lastit.it_value.tv_sec;

}
int main(void)
{
  my_alarm(1);
  for(int i = 0; ; i++)
  {
    printf("%d \n", i);
  }
  return 0;
}
```

## 3、信号捕捉函数

### signal()

```c
#include <signal.h>
typedef void (*sighandler_t)(int);
sighandler_t signal(int signum, sighandler_t handler);
```

参数：signum，信号；handler，信号的回调函数，想让该信号进行的处理放这个回调函数里的。

返回值：成功返回信号处理程序的前一个值，失败返回SIG_ERR。

```c
#include <sys/time.h>
#include <stdio.h>
#include <signal.h>
#include <stdlib.h>

// 此函数运行在用户空间，由内核调用
// 函数返回时执行特殊的系统调用sigreturn再次进入内核
void func(int sigo)
{
  printf("hello signal SIGALRM!\n");
}
int main(void)
{
  struct itimerval it, lastit;

  signal(SIGALRM, func); // 注册SIGALRM信号的捕捉处理函数

  it.it_value.tv_sec = 5;    //第一次定时5s
  it.it_value.tv_usec = 0;

  it.it_interval.tv_sec = 3;  // 后面都是定时3s
  it.it_interval.tv_usec = 0;

  int ret = setitimer(ITIMER_REAL, &it, &lastit);
  if(ret == -1)
  {
    perror("setitimer");
    exit(1);
  }

  while(1);
  return 0;
}
```

### sigaction()

```c
#include <signal.h>
struct sigaction {
    void     (*sa_handler)(int);  // 回调函数
    void     (*sa_sigaction)(int, siginfo_t *, void *); 
    sigset_t   sa_mask; // 信号捕捉函数期间的信号屏蔽字
    int        sa_flags;  
    void     (*sa_restorer)(void); // 已废弃，不看
};

int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact);
```

sa_restorer：已过时，不应该使用。POSIX.1标准将不指定该元素。（弃用）

sa_sigaction：当sa_flags被指定为SA_SIGINFO标志时，使用该信号处理程序。（很少用）

重点：

sa_handler：指定该信号捕捉后的处理函数名（即注册函数）。也可以赋值为SIG_IGN表示忽略 或 SIG_DFL 表示执行默认动作。

sa_mask：调用信号处理函数时，所要屏蔽的信号集合（信号屏蔽字）。**注意：仅在处理函数被调用期间屏蔽生效，是临时设置**。

sa_flags：一般设置为0，表示使用默认属性。

```
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <stdlib.h>
void catchsig(int signo)
{
	printf("%d signal is catched\n",signo);
}

int main(void)
{
	int ret;
	struct sigaction act;
	
	act.sa_handler = catchsig;
	sigemptyset(&act.sa_mask);
	sigaddset(&act.sa_mask, SIGQUIT); //  3) SIGQUIT (ctr + \)
	act.sa_flags = 0; // 默认属性 信号捕捉函数执行期间，自动屏蔽本信号
	
	ret = sigaction(SIGINT, &act, NULL); // 2) SIGINT(ctrl + c)
	if(ret < 0)
	{
		perror("sigaction error");
		exit(1);
	}
	while(1);
	return 0;
}
```



## 4、信号集操作函数

内核通过读取未决信号集来判断信号是否应被处理。信号屏蔽字mask可以影响未决信号集。所以可以通过在应用程序中自定义set来改变mask，从而屏蔽指定信号。

### 信号集设定

sigset_t	set;	// typdef unsigned long sigset_t; 本质上是位图	

| 函数                                              | 描述                       | 返回值                       |
| ------------------------------------------------- | -------------------------- | ---------------------------- |
| int sigemptyset(sigset_t *set);                   | 将某个信号集清零           | 成功：0；失败：-1            |
| int sigfillset(sigset_t *set);                    | 将某个信号集置1            | 成功：0；失败：-1            |
| int sigaddset(sigset_t set, int signum);          | 将某个信号加入信号集       | 成功：0；失败：-1            |
| int sigdelset(sigset_t set, int signum);          | 将某个信号清出信号集       | 成功：0；失败：-1            |
| int sigismember(const sigset_t *set, int signum); | 判断某个信号是否在信号集中 | 在集合：1；不在：0；出错：-1 |

### sigprocmask函数

用来**屏蔽信号**、**解除信号屏蔽**。其本质，读取或者修改进程的信号屏蔽字（pcb中）。

**再说一遍，屏蔽信号：只是将信号处理延后执行（延至解除屏蔽）；而忽略表示将信号丢弃。**

int sigprocmask(int how, const sigset_t *set, sigset_t *oldset);	成功：0；失败：-1，设置errno。

参数：

set：传入参数，是一个位图，set中哪位置1，就表示当前进程屏蔽那个信号。

oldset：传出参数，保存旧的信号屏蔽字。

how：假定当前信号屏蔽字为mask

1. SIG_BLOCK：set表示需要屏蔽的信号，相当 mask |= set
2. SIG_UNBLOCK：set表示需要解除屏蔽的信号，相当 mask = mask & (~set)
3. SIG_SETMASK：set用于替代原始屏蔽集的新屏蔽集，相当 mask = set，若调用sigprocmask解除了对当前若干个信号的阻塞，则在sigprocmask返回前，至少将其中一个信号递达。

### sigpending函数

读取当前进程的未决信号集。

int sigpending(sigset_t *set);	set：传出参数	返回值：成功：0；失败：-1，设置errno

```c
// 打印当前进程所有的未决信号集
#include <stdio.h>
#include <signal.h>
#include <unistd.h>
void printpend(sigset_t *ped)
{
    int i;
    for(i = 1; i < 32; i++)
    {
        if(sigismember(ped, i) == 1)
        {
            putchar('1');
        }
        else
        {
            putchar('0');
        }
    }
    printf("\n");
}
int main(void)
{
    sigset_t myset, oldset, ped;
    
    sigemptyset(&myset);  // 清零

    sigaddset(&myset, SIGQUIT); // 将 3) SIGQUIT(ctrl + \) 信号加入到myset信号集
    sigaddset(&myset, SIGINT); // 2) SIGINT(ctrl + c)
    sigaddset(&myset, SIGTSTP); // 20) SIGTSTP(ctrl +z)

    // 9)SIGKILL、19)SIGSTOP信号，不允许忽略或者捕获，只能执行默认动作。甚至不能将其阻塞。
    // 所以下面这两句其实没什么用
    sigaddset(&myset, SIGKILL);
    sigaddset(&myset, SIGSTOP);

    
    sigprocmask(SIG_BLOCK, &myset, &oldset); // 将myset信号集去影响阻塞信号集
    
    while(1){
        sigpending(&ped); // 获取当前进程的未决信号集。
   		printpend(&ped);
        sleep(1);
    }
	return 0;
}
```

## 5、信号捕捉特性

1. 进程正常运行时，默认PCB中有一个信号屏蔽字，假定为⭐，它决定了进程自动屏蔽哪些信号。当注册了某个信号捕捉函数，捕捉到该信号后，要调用该函数。而该函数可能会执行很长时间，在这期间所屏蔽的信号不由⭐来指定，而是由sa_mask来指定。调用完信号处理函数，再恢复为⭐。
2. xxx信号捕捉函数执行期间，xxx信号自动屏蔽。
3. 阻塞的常规信号不支持排队，产生多次只记录一次。（后32个实时信号支持排队）

## 6、内核实现信号捕捉过程

![内核实现信号捕捉过程.png](https://i.loli.net/2021/07/05/hFPQlETXJvb3zHe.png)

