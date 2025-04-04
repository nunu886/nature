#ifndef NATURE_LINKCO_H
#define NATURE_LINKCO_H

#include "nutils/nutils.h"
#include "runtime.h"

extern linkco_t *global_linkco_cache;
extern mutex_t global_linkco_locker;

// 从 p 或者 global 中申请一个 linkco_t
linkco_t *rti_acquire_linkco();

void rti_release_linkco(linkco_t *linkco);

typedef struct {
    linkco_t *head;        // default null
    linkco_t *rear;        // default null
    int64_t count;         // default 0
    pthread_mutex_t locker;// default 0
} rt_linkco_list_t;


static inline void linkco_list_push(rt_linkco_list_t *list, void *value) {
    assert(list);

    linkco_t *new_linkco = rti_acquire_linkco();
    assert(new_linkco->next == NULL);
    assert(new_linkco->prev == NULL);

    new_linkco->co = value;
    if (list->head == NULL) {
        assert(list->rear == NULL);

        //        list->head = new_linkco;
        //        list->rear = new_linkco;
        rti_write_barrier_ptr(&list->head, new_linkco, false);
        rti_write_barrier_ptr(&list->rear, new_linkco, false);
    } else {
        assert(list->rear);

        //        list->rear->next = new_linkco;
        rti_write_barrier_ptr(&list->rear->next, new_linkco, false);

        //        new_linkco->prev = list->rear;
        rti_write_barrier_ptr(&new_linkco->prev, list->rear, false);

        //        list->rear = new_linkco;
        rti_write_barrier_ptr(&list->rear, new_linkco, false);
    }

    list->count++;
}

// 默认从 header pop, 所以 pop_linkco 没有 prev
static inline void *linkco_list_pop(rt_linkco_list_t *list) {
    assert(list);
    if (list->head == NULL) {
        assert(list->rear == NULL);
        return NULL;
    }

    assertf(list->head->co, "linkco head %p value empty", list->head);

    linkco_t *pop_linkco = list->head;

    //    list->head = list->head->next;
    rti_write_barrier_ptr(&list->head, list->head->next, false);


    if (list->head == NULL) {
        assertf(list->count == 1, "list head is null, but list count = %d", list->count);
        //        list->rear = NULL;
        rti_write_barrier_ptr(&list->rear, NULL, false);
    } else {
        //        list->head->prev = NULL;
        rti_write_barrier_ptr(&list->head->prev, NULL, false);
    }

    list->count--;

    void *value = pop_linkco->co;

    pop_linkco->next = NULL;
    rti_release_linkco(pop_linkco);

    return value;
}


static inline void linkco_list_lock_push(rt_linkco_list_t *list, void *value) {
    pthread_mutex_lock(&list->locker);
    linkco_list_push(list, value);
    pthread_mutex_unlock(&list->locker);
}

static inline void linkco_list_push_head(rt_linkco_list_t *list, void *value) {
    assert(list);
    assert(value);

    linkco_t *new_linkco = rti_acquire_linkco();
    new_linkco->co = value;

    if (list->head == NULL) {
        assert(list->rear == NULL);
        list->head = new_linkco;
        list->rear = new_linkco;
    } else {
        assert(list->head);
        new_linkco->next = list->head;
        list->head->prev = new_linkco;
        list->head = new_linkco;
    }

    list->count++;
}

static inline void linkco_list_lock_push_head(rt_linkco_list_t *list, void *value) {
    pthread_mutex_lock(&list->locker);
    linkco_list_push_head(list, value);
    pthread_mutex_unlock(&list->locker);
}

static inline void *linkco_list_lock_pop(rt_linkco_list_t *list) {
    pthread_mutex_lock(&list->locker);
    void *value = linkco_list_pop(list);
    pthread_mutex_unlock(&list->locker);
    return value;
}

static inline bool linkco_list_lock_empty(rt_linkco_list_t *list) {
    assert(list);
    pthread_mutex_lock(&list->locker);

    bool empty = list->count == 0;

    pthread_mutex_unlock(&list->locker);
    return empty;
}

static inline void linkco_list_remove(rt_linkco_list_t *list, linkco_t *linkco) {
    assert(list);

    // 调整链表关系
    if (linkco->prev == NULL) {
        assert(list->head == linkco);
        list->head = linkco->next;
    } else {
        linkco->prev->next = linkco->next;
    }

    // 调整链表关系
    if (linkco->next == NULL) {
        assert(list->rear == linkco);
        list->rear = linkco->prev;
    } else {
        linkco->next->prev = linkco->prev;
    }

    list->count--;
    rti_release_linkco(linkco);
}

static inline void linkco_list_lock_remove(rt_linkco_list_t *list, linkco_t *linkco) {
    pthread_mutex_lock(&list->locker);
    linkco_list_remove(list, linkco);
    pthread_mutex_unlock(&list->locker);
}

#endif//NATURE_LINKCO_H
