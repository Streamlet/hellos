#ifndef __INT_H_INCLUDED__
#define __INT_H_INCLUDED__

extern void enable_irq(unsigned char irq_num);
extern void disable_irq(unsigned char irq_num);
extern void handle_interrupt(unsigned char int_num);

#endif // __INT_H_INCLUDED__
