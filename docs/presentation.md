1. 性能测试  
   展示块设备的读入速度测试。
   ```shell
   cd ~/svdrivers/qemu
   make run
   ```
3. 展示可作为隔离域加入Alien中，并且支持Alien的特有域功能。  
   - 可以在崩溃后恢复并继续执行操作。  
     ```shell
     cd ~/Alien
     make run
     ```
   - 可以动态的被加载、切换  
     ```shell
     LOG= make run
     dtest
     dtest
     ```

