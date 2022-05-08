#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>
#include <unistd.h>

typedef struct axi_int_test {
    volatile uint32_t start_counter; /* 0x0000 */
    volatile uint32_t counter_1;     /* 0x0004 */
    volatile uint32_t counter_2;     /* 0x0008 */
    volatile uint32_t clear_int;     /* 0x000B */
} axi_int_test_t;

static int stop_thread = 0;

static void* thread_func(void* thread_data) {
    char* device_path = (char*) thread_data;
    pid_t pid = syscall(__NR_gettid);

    /* open device and create memmory map */

    int fd = open(device_path, O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("open");
        exit(1);
    }
    printf("[%04d] opened %s\n", pid, device_path);

    volatile axi_int_test_t* registers = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (registers == MAP_FAILED) {
        perror("mmap");
        exit(1);
    }

    /* reset the counter  */

    registers->start_counter = 0;

    registers->clear_int = 1;
    ssize_t len = write(fd, "0x1\n", 4);
    if (len < 0) {
        perror("write");
        exit(1);
    }

    registers->start_counter = 1;

    /* main loop, wait for interrupts */

    for (int i = 0; i < 100 && !stop_thread; i++) {
        uint32_t info = 0;

        /* wait for interrupt */

        len = read(fd, &info, sizeof(info));
        if (len < 0) {
                perror("read");
                exit(1);
        }

        /* clear any pending interrupt */

        registers->clear_int = 1;
        len = write(fd, "0x1\n", 4);
        if (len < 0) {
            perror("write");
            exit(1);
        }

        printf("[%04d] CONTROL=%d COUNTER1=0x%08X COUNTER2=0x%08X\n",
            pid,
            registers->start_counter,
            registers->counter_1,
            registers->counter_2
        );
    }

    /* cleanup */

    if (close(fd) < 0) {
        perror("close");
    }

    printf("[%04d] closed %s\n", pid, device_path);

    if (munmap((void*) registers, 4096) < 0) {
        perror("munmap");
    }

    return NULL;
}

static void sigint_handler(int signal) {
    (void) signal;

    printf("SIGINT received, stopping threads...\n");

    stop_thread = 1;
}

int main() {
    pthread_t t1, t2;

    errno = pthread_create(&t1, NULL, thread_func, "/dev/uio0");
    if (errno != 0) {
        perror("pthread_create");
        exit(1);
    }

    sleep(2);

    errno = pthread_create(&t2, NULL, thread_func, "/dev/uio1");
    if (errno != 0) {
        perror("pthread_create");
        exit(1);
    }

    if (signal(SIGINT, sigint_handler) == SIG_ERR) {
        perror("signal");
        exit(1);
    }

    errno = pthread_join(t1, NULL);
    if (errno != 0) {
        perror("pthread_join");
        exit(1);
    }

    errno = pthread_join(t2, NULL);
    if (errno != 0) {
        perror("pthread_join");
        exit(1);
    }

    return 0;
}