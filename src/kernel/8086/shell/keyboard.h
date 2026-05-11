#ifndef __KEYBOARD_H_INCLUDED__
#define __KEYBOARD_H_INCLUDED__

void keyboard_init();
void keyboard_interrupt_handler(unsigned char scancode);
unsigned short keyboard_read();

#endif // __KEYBOARD_H_INCLUDED__
