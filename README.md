# SMTime
Check if system time is altered or not offline using my code. Remember, if you restart your iphone, you will need internet once to callibrate system time.

# How to use?
```
SMTime.getTime { success, date, message in
    // ... your code
}
```
- `success: true`: It means the system time is not changed.
- `success: false`: It means the system time is changed.
- `message`: Use message to display default message, or you can use your own messages as well.
