Работа с системой Kubernetes»
Ссылка на репозиторий: https://github.com/declassified24/lab6
Цель лабораторной работы: Реализовать и документировать кластер Kubernetes с балансировкой нагрузки. Приложение, работу которого обеспечивает кластер – сервер приложений Nginx. Реализовать, насколько возможно, сценарий высокой загрузки кластера и распределения нагрузки между его узлами.
1. Подготовка рабочего окружения
1.1. Установка необходимых инструментов
# Запустите PowerShell от имени Администратора
# Установка Chocolatey (пакетный менеджер)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
# Установка Minikube и Kubernetes CLI
choco install minikube kubernetes-cli docker-desktop -y
# Перезагрузка системы после установки
Restart-Computer
1.2. Проверка установки
# Проверка версий
minikube version
kubectl version --client
docker --version
Ожидаемый вывод:
minikube version: v1.37.0
commit: 65318f4cfff9c12cc87ec9eb8f4cdd57b25047f3
Client Version: v1.34.2
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Docker version 24.0.6, build ed223bc
 
 
1.3. Запуск Kubernetes кластера
# Запуск кластера с 3 узлами
minikube start --nodes=3 --cpus=2 --memory=4096 --driver=docker
# Проверка состояния кластера
kubectl cluster-info
kubectl get nodes



Вывод:
minikube 1.32.0 is available. Downloading: https://github.com/kubernetes/minikube/releases/download/v1.32.0/minikube-windows-amd64.exe
✅  Using the docker driver based on user configuration
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.28.0 on Docker 24.0.7 ...
    ▪ Generating certificates and keys ...
    ▪ Booting up control plane ...
    ▪ Configuring RBAC rules ...
🔗  Configuring bridge CNI (Container Networking Interface) ...
🔎  Verifying Kubernetes components...
    ▪ Using image gcr.io/k8s-minikube/storage-provisioner:v5
🌟  Enabled addons: storage-provisioner, default-storageclass
👍  Starting node minikube-m02 in cluster minikube
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🐳  Preparing Kubernetes v1.28.0 on Docker 24.0.7 ...
🔎  Verifying Kubernetes components...
👍  Starting node minikube-m03 in cluster minikube
🔥  Creating docker container (CPUs=2, Memory=4096MB) ...
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
Kubernetes control plane is running at https://127.0.0.1:64915
CoreDNS is running at https://127.0.0.1:64915/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   58s   v1.28.0
minikube-m02   Ready    <none>          32s   v1.28.0
minikube-m03   Ready    <none>          18s   v1.28.0
 
 
2. Создание структуры проекта и манифестов Kubernetes
2.1. Инициализация проекта 
# Создание директории проекта
mkdir C:\k8s-lab
cd C:\k8s-lab
mkdir manifests
# Инициализация git репозитория
git init
echo "# Kubernetes Load Balancing Lab" > README.md
git add .
git commit -m "Initial commit: project structure"
 
2.2. Создание Deployment манифеста для Nginx
# Создаем файл манифеста
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 6
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
"@ | Out-File -FilePath manifests/nginx-deployment.yaml -Encoding utf8
2.3. Создание Service манифеста для балансировки нагрузки
# Service для балансировки нагрузки
@"
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
"@ | Out-File -FilePath manifests/nginx-service.yaml -Encoding utf8
2.4. Создание Horizontal Pod Autoscaler
# Horizontal Pod Autoscaler
@"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-deployment
  minReplicas: 3
  maxReplicas: 15
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
"@ | Out-File -FilePath manifests/nginx-hpa.yaml -Encoding utf8
3. Развертывание приложения и настройка балансировки
3.1. Применение манифестов Kubernetes
# Применяем наши манифесты
minikube kubectl -- apply -f manifests/

# Проверяем развертывание
minikube kubectl -- get deployments
minikube kubectl -- get pods -o wide
minikube kubectl -- get services
minikube kubectl -- get hpa
Вывод:
deployment.apps/nginx-deployment configured
horizontalpodautoscaler.autoscaling/nginx-hpa unchanged
service/nginx-service unchanged
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3/6     6            3           51m
NAME                                READY   STATUS              RESTARTS   AGE   IP           NODE           NOMINATED NODE   READINESS GATES
nginx-deployment-5f46969478-57j42   1/1     Running             0          51m   10.244.0.4   minikube       <none>           <none>
nginx-deployment-5f46969478-bfpbf   1/1     Running             0          51m   10.244.2.2   minikube-m03   <none>           <none>
nginx-deployment-5f46969478-cp5wc   0/1     ContainerCreating   0          0s    <none>       minikube-m02   <none>           <none>
nginx-deployment-5f46969478-nrwqz   1/1     Running             0          51m   10.244.2.3   minikube-m03   <none>           <none>
nginx-deployment-5f46969478-ntrdr   0/1     ContainerCreating   0          0s    <none>       minikube-m02   <none>           <none>
nginx-deployment-5f46969478-nx6sx   0/1     ContainerCreating   0          0s    <none>       minikube       <none>           <none>
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes      ClusterIP      10.96.0.1      <none>        443/TCP        61m
nginx-service   LoadBalancer   10.107.15.36   127.0.0.1     80:30827/TCP   51m
NAME        REFERENCE                     TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
nginx-hpa   Deployment/nginx-deployment   cpu: 2%/70%   3         15        3          51m
 
3.2. Ожидание запуска подов
# Дожидаемся пока все поды станут Ready
minikube kubectl -- wait --for=condition=ready pod --selector=app=nginx --timeout=300s
# Проверяем финальный статус
minikube kubectl -- get pods
Вывод:
pod/nginx-deployment-5f46969478-57j42 condition met
pod/nginx-deployment-5f46969478-bfpbf condition met
pod/nginx-deployment-5f46969478-nrwqz condition met
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-5f46969478-57j42   1/1     Running   0          52m
nginx-deployment-5f46969478-bfpbf   1/1     Running   0          52m
nginx-deployment-5f46969478-nrwqz   1/1     Running   0          52m
 
3.3. Настройка LoadBalancer
# ОТКРОЙТЕ НОВОЕ ОКНО PowerShell и выполните:
minikube tunnel
# В основном окне проверяем сервис (ждем появления EXTERNAL-IP)
minikube kubectl -- get services –watch
Вывод:
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
kubernetes      ClusterIP      10.96.0.1      <none>        443/TCP        66m
nginx-service   LoadBalancer   10.107.15.36   127.0.0.1     80:30827/TCP   56m
 
 

4. Реализация сценария высокой нагрузки
4.1. Создание скрипта для генерации нагрузки. Запуск теста высокой нагрузки
Write-Host "=== SUPER LOAD TEST ===" -ForegroundColor Red
Write-Host "Creating massive HTTP load to guarantee HPA scaling..." -ForegroundColor Yellow

$url = "http://127.0.0.1"
$duration = 600  # 10 минут для гарантии

# Супер-интенсивная функция нагрузки
$superLoadScript = {
    param($url, $threadId, $duration)
    
    $endTime = [DateTime]::Now.AddSeconds($duration)
    $client = New-Object System.Net.WebClient
    
    while ([DateTime]::Now -lt $endTime) {
        try {
            # ОЧЕНЬ быстрые запросы без задержек
            $client.DownloadString($url) | Out-Null
            $client.DownloadString($url) | Out-Null
            $client.DownloadString($url) | Out-Null
        } catch {
            # Игнорируем все ошибки
        }
    }
}

Write-Host "Starting 50 PARALLEL SUPER LOAD GENERATORS..." -ForegroundColor Green
$jobs = @()
for ($i = 0; $i -lt 50; $i++) {
    $job = Start-Job -ScriptBlock $superLoadScript -ArgumentList $url, $i, $duration
    $jobs += $job
}

Write-Host "50 load generators started! Monitoring intensively..." -ForegroundColor Cyan

# Интенсивный мониторинг
for ($i = 1; $i -le 50; $i++) {
    Start-Sleep 6
    
    Clear-Host
    Write-Host "=== SUPER LOAD TEST PROGRESS ===" -ForegroundColor Red
    Write-Host "Check $i of 50 | Elapsed: $($i * 6) seconds" -ForegroundColor White
    
    # Проверяем ВСЕ метрики
    Write-Host "`n📊 PODS STATUS:" -ForegroundColor Yellow
    $allPods = kubectl get pods -l app=nginx 2>$null
    $allPods
    $podCount = ($allPods | Measure-Object -Line).Lines - 1
    
    Write-Host "`n📈 HPA STATUS:" -ForegroundColor Yellow
    $hpaOutput = kubectl get hpa nginx-hpa 2>$null
    $hpaOutput
    
    Write-Host "`n🔥 CPU METRICS:" -ForegroundColor Yellow
    try {
        $cpuMetrics = kubectl top pods -l app=nginx 2>$null
        if ($cpuMetrics) {
            $cpuMetrics
            # Считаем общую CPU нагрузку
            $totalCPU = ($cpuMetrics | Select-Object -Skip 1 | ForEach-Object { 
                [int]($_.Split()[1].Replace('m','')) 
            } | Measure-Object -Sum).Sum
            Write-Host "Total CPU load: ${totalCPU}m" -ForegroundColor White
        }
    } catch {
        Write-Host "Metrics still initializing..." -ForegroundColor Gray
    }
    
    Write-Host "`n🔍 DETAILED HPA:" -ForegroundColor Yellow
    try {
        $hpaDetails = kubectl get hpa nginx-hpa -o json | ConvertFrom-Json
        $currentCPU = $hpaDetails.status.currentCPUUtilizationPercentage
        $desiredReplicas = $hpaDetails.status.desiredReplicas
        
        Write-Host "Current CPU: $currentCPU%" -ForegroundColor White
        Write-Host "Desired Replicas: $desiredReplicas" -ForegroundColor White
        Write-Host "Current Replicas: $($hpaDetails.status.currentReplicas)" -ForegroundColor White
        
        # Проверяем scaling условия
        if ($desiredReplicas -gt $podCount) {
            Write-Host "`n🎉 HPA SCALING DETECTED!" -ForegroundColor Green
            Write-Host "Scaling from $podCount to $desiredReplicas pods" -ForegroundColor Green
        }
        
        if ($currentCPU -gt 70) {
            Write-Host "`n🚀 CPU THRESHOLD EXCEEDED: $currentCPU%" -ForegroundColor Red
        }
    } catch {
        Write-Host "HPA details not available yet" -ForegroundColor Gray
    }
    
    Write-Host "`nActive load generators: $($jobs.Count)" -ForegroundColor Gray
    
    # Если видим scaling - выходим
    if ($podCount -gt 3) {
        Write-Host "`n🎊 SUCCESS! POD COUNT INCREASED TO: $podCount" -ForegroundColor Green
        break
    }
}

# Останавливаем нагрузку
Write-Host "`nStopping load generators..." -ForegroundColor Yellow
$jobs | Remove-Job -Force

Write-Host "=== FINAL STATE ===" -ForegroundColor Cyan
kubectl get all -l app=nginx
 
 
 

 
4.2. Мониторинг автоматического масштабирования
cd C:\k8s-lab

Write-Host "Starting cluster monitoring..." -ForegroundColor Cyan

$testStartTime = Get-Date
while ($true) {
    $currentTime = Get-Date
    $elapsed = [math]::Round(($currentTime - $testStartTime).TotalSeconds, 1)
    
    Clear-Host
    Write-Host "=== KUBERNETES CLUSTER MONITORING ===" -ForegroundColor Cyan
    Write-Host "Elapsed time: ${elapsed}s" -ForegroundColor Yellow
    Write-Host "Test start: $testStartTime" -ForegroundColor Gray
    
    Write-Host "`n[PODS STATUS]" -ForegroundColor Green
    kubectl get pods -o wide
    
    Write-Host "`n[HPA STATUS]" -ForegroundColor Green
    kubectl get hpa
    
    Write-Host "`n[NODES STATUS]" -ForegroundColor Green
    kubectl get nodes
    
    Write-Host "`n[PODS BY NODE]" -ForegroundColor Green
    kubectl get pods -o wide | Group-Object {$_.Split()[6]} | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count) pods" -ForegroundColor White
    }
    
    Write-Host "`nLast update: $(Get-Date)" -ForegroundColor Gray
    Write-Host "Press Ctrl+C to stop monitoring..." -ForegroundColor DarkGray
    
    Start-Sleep 10
}
Фактический вывод состояния кластера под нагрузкой:
=== KUBERNETES CLUSTER MONITORING ===
Elapsed time: 406.2s
Test start: 11/23/2025 02:20:12

[PODS STATUS]
NAME                               READY   STATUS    RESTARTS   AGE     IP            NODE           NOMINATED NODE   READINESS GATES
nginx-deployment-8c9c54f7b-25m8k   1/1     Running   0          49s     10.244.1.18   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-2tlz5   1/1     Running   0          112s    10.244.2.11   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-4qc8w   1/1     Running   0          2m54s   10.244.2.10   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-67bcn   1/1     Running   0          49s     10.244.1.19   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-6tf2f   1/1     Running   0          49s     10.244.0.15   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-8n9lx   1/1     Running   0          14m     10.244.1.12   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-9cdw9   1/1     Running   0          112s    10.244.1.17   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-d2d57   1/1     Running   0          49s     10.244.2.13   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-f4jmb   1/1     Running   0          2m54s   10.244.1.16   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-h5pzc   1/1     Running   0          49s     10.244.2.12   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-htl7n   1/1     Running   0          14m     10.244.2.8    minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-jdnkc   1/1     Running   0          2m54s   10.244.0.12   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-l7lzq   1/1     Running   0          14m     10.244.0.10   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-l9524   1/1     Running   0          112s    10.244.0.13   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-tqw97   1/1     Running   0          49s     10.244.0.14   minikube       <none>           <none>

[HPA STATUS]
NAME        REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
nginx-hpa   Deployment/nginx-deployment   cpu: 164%/70%   3         15        15         3h13m

[NODES STATUS]
NAME           STATUS   ROLES           AGE     VERSION
minikube       Ready    control-plane   3h23m   v1.34.0
minikube-m02   Ready    <none>          3h22m   v1.34.0
minikube-m03   Ready    <none>          3h20m   v1.34.0

[PODS BY NODE]
  : 16 pods


 
 
5. Анализ распределения нагрузки
5.1. Проверяем масштабирование после теста
# Проверяем результаты нагрузочного тестирования
Write-Host "`n=== CHECKING HPA SCALING ===" -ForegroundColor Cyan

Write-Host "`n1. Current pod count:" -ForegroundColor Yellow
kubectl get pods -l app=nginx

Write-Host "`n2. HPA status:" -ForegroundColor Yellow
kubectl get hpa

Write-Host "`n3. CPU usage metrics:" -ForegroundColor Yellow
kubectl top pods -l app=nginx 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing metrics-server..." -ForegroundColor Yellow
    minikube addons enable metrics-server
    Write-Host "Waiting for metrics..." -ForegroundColor Yellow
    Start-Sleep 30
    kubectl top pods -l app=nginx
}

Write-Host "`n4. HPA events:" -ForegroundColor Yellow
kubectl describe hpa nginx-hpa | Select-String -Pattern "Events:" -Context 0,10

 

Фактический вывод:
=== CHECKING HPA SCALING ===

1. Current pod count:
NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-8c9c54f7b-25m8k   1/1     Running   0          2m50s
nginx-deployment-8c9c54f7b-2tlz5   1/1     Running   0          3m53s
nginx-deployment-8c9c54f7b-4qc8w   1/1     Running   0          4m55s
nginx-deployment-8c9c54f7b-67bcn   1/1     Running   0          2m50s
nginx-deployment-8c9c54f7b-6tf2f   1/1     Running   0          2m50s
nginx-deployment-8c9c54f7b-8n9lx   1/1     Running   0          16m
nginx-deployment-8c9c54f7b-9cdw9   1/1     Running   0          3m53s
nginx-deployment-8c9c54f7b-d2d57   1/1     Running   0          2m50s
nginx-deployment-8c9c54f7b-f4jmb   1/1     Running   0          4m55s
nginx-deployment-8c9c54f7b-h5pzc   1/1     Running   0          2m50s
nginx-deployment-8c9c54f7b-htl7n   1/1     Running   0          16m
nginx-deployment-8c9c54f7b-jdnkc   1/1     Running   0          4m55s
nginx-deployment-8c9c54f7b-l7lzq   1/1     Running   0          16m
nginx-deployment-8c9c54f7b-l9524   1/1     Running   0          3m53s
nginx-deployment-8c9c54f7b-tqw97   1/1     Running   0          2m50s

2. HPA status:
NAME        REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
nginx-hpa   Deployment/nginx-deployment   cpu: 115%/70%   3         15        15         3h15m

3. CPU usage metrics:
NAME                               CPU(cores)   MEMORY(bytes)
nginx-deployment-8c9c54f7b-25m8k   66m          7Mi
nginx-deployment-8c9c54f7b-2tlz5   62m          7Mi
nginx-deployment-8c9c54f7b-4qc8w   51m          7Mi
nginx-deployment-8c9c54f7b-67bcn   63m          7Mi
nginx-deployment-8c9c54f7b-6tf2f   52m          7Mi
nginx-deployment-8c9c54f7b-8n9lx   57m          7Mi
nginx-deployment-8c9c54f7b-9cdw9   52m          7Mi
nginx-deployment-8c9c54f7b-d2d57   64m          7Mi
nginx-deployment-8c9c54f7b-f4jmb   77m          7Mi
nginx-deployment-8c9c54f7b-h5pzc   58m          7Mi
nginx-deployment-8c9c54f7b-htl7n   71m          7Mi
nginx-deployment-8c9c54f7b-jdnkc   43m          7Mi
nginx-deployment-8c9c54f7b-l7lzq   36m          7Mi
nginx-deployment-8c9c54f7b-l9524   52m          7Mi
nginx-deployment-8c9c54f7b-tqw97   63m          7Mi

4. HPA events:

> Events:
    Type     Reason                        Age                   From                       Message
    ----     ------                        ----                  ----                       -------
    Normal   SuccessfulRescale             24m                   horizontal-pod-autoscaler  New size: 4; reason: All
metrics below target
    Warning  FailedGetResourceMetric       15m (x2 over 15m)     horizontal-pod-autoscaler  failed to get cpu
utilization: unable to get metrics for resource cpu: no metrics returned from resource metrics API
    Warning  FailedComputeMetricsReplicas  15m (x2 over 15m)     horizontal-pod-autoscaler  invalid metrics (1 invalid
out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: unable to get
metrics for resource cpu: no metrics returned from resource metrics API
    Warning  FailedGetResourceMetric       14m (x12 over 3h14m)  horizontal-pod-autoscaler  failed to get cpu
utilization: did not receive metrics for targeted pods (pods might be unready)
    Warning  FailedComputeMetricsReplicas  14m (x12 over 3h14m)  horizontal-pod-autoscaler  invalid metrics (1 invalid
out of 1), first error is: failed to get cpu resource metric value: failed to get cpu utilization: did not receive
metrics for targeted pods (pods might be unready)
    Normal   SuccessfulRescale             10m (x6 over 3h9m)    horizontal-pod-autoscaler  New size: 3; reason: All
metrics below target
    Normal   SuccessfulRescale             4m55s (x3 over 116m)  horizontal-pod-autoscaler  New size: 6; reason: cpu
resource utilization (percentage of request) above target
    Normal   SuccessfulRescale             3m53s                 horizontal-pod-autoscaler  New size: 9; reason: cpu
resource utilization (percentage of request) above target
5.2. Анализ распределения нагрузки
# Проверка распределения подов по узлам
kubectl get pods -l app=nginx -o wide
Вывод:
>> kubectl get pods -l app=nginx -o wide
>>
NAME                               READY   STATUS    RESTARTS   AGE     IP            NODE           NOMINATED NODE   READINESS GATES
nginx-deployment-8c9c54f7b-25m8k   1/1     Running   0          4m20s   10.244.1.18   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-2tlz5   1/1     Running   0          5m23s   10.244.2.11   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-4qc8w   1/1     Running   0          6m25s   10.244.2.10   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-67bcn   1/1     Running   0          4m20s   10.244.1.19   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-6tf2f   1/1     Running   0          4m20s   10.244.0.15   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-8n9lx   1/1     Running   0          17m     10.244.1.12   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-9cdw9   1/1     Running   0          5m23s   10.244.1.17   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-d2d57   1/1     Running   0          4m20s   10.244.2.13   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-f4jmb   1/1     Running   0          6m25s   10.244.1.16   minikube-m02   <none>           <none>
nginx-deployment-8c9c54f7b-h5pzc   1/1     Running   0          4m20s   10.244.2.12   minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-htl7n   1/1     Running   0          17m     10.244.2.8    minikube-m03   <none>           <none>
nginx-deployment-8c9c54f7b-jdnkc   1/1     Running   0          6m25s   10.244.0.12   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-l7lzq   1/1     Running   0          17m     10.244.0.10   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-l9524   1/1     Running   0          5m23s   10.244.0.13   minikube       <none>           <none>
nginx-deployment-8c9c54f7b-tqw97   1/1     Running   0          4m20s   10.244.0.14   minikube       <none>           <none>
 
 
5.3. Визуализация архитектуры кластера
 
6. Финальная проверка работоспособности
6.1. Проверка состояния кластера
# Общая проверка состояния
kubectl get nodes,deployments,services,hpa,pods

# Проверка логов для демонстрации работы
kubectl logs deployment/nginx-deployment --tail=5
Вывод:
>>
NAME                STATUS   ROLES           AGE     VERSION
node/minikube       Ready    control-plane   3h37m   v1.34.0
node/minikube-m02   Ready    <none>          3h36m   v1.34.0
node/minikube-m03   Ready    <none>          3h34m   v1.34.0

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   3/3     3            3           3h26m

NAME                    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/kubernetes      ClusterIP      10.96.0.1      <none>        443/TCP        3h37m
service/nginx-service   LoadBalancer   10.106.99.31   127.0.0.1     80:32462/TCP   129m

NAME                                            REFERENCE                     TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/nginx-hpa   Deployment/nginx-deployment   cpu: 2%/70%   3         15        3          3h26m

NAME                                   READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-8c9c54f7b-8n9lx   1/1     Running   0          28m
pod/nginx-deployment-8c9c54f7b-htl7n   1/1     Running   0          28m
pod/nginx-deployment-8c9c54f7b-l7lzq   1/1     Running   0          28m
Found 3 pods, using pod/nginx-deployment-8c9c54f7b-8n9lx
10.244.1.1 - - [22/Nov/2025:23:40:24 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.34" "-"
10.244.1.1 - - [22/Nov/2025:23:40:33 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.34" "-"
10.244.1.1 - - [22/Nov/2025:23:40:34 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.34" "-"
10.244.1.1 - - [22/Nov/2025:23:40:43 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.34" "-"
10.244.1.1 - - [22/Nov/2025:23:40:46 +0000] "GET / HTTP/1.1" 200 615 "-" "kube-probe/1.34" "-"
 
6.2. Очистка ресурсов (опционально)
# Удаление созданных ресурсов
kubectl delete -f manifests/

# Остановка Minikube кластера
minikube stop


Заключение
Задание выполнено успешно. Реализован и протестирован кластер Kubernetes с балансировкой нагрузки, включая:
1.	✅ Развертывание Nginx в виде Deployment с 6 репликами
2.	✅ Настройка LoadBalancer Service для распределения входящего трафика
3.	✅ Конфигурация Horizontal Pod Autoscaler для автоматического масштабирования
4.	✅ Реализация сценария высокой нагрузки с генерацией 50 параллельных запросов
5.	✅ Демонстрация распределения нагрузки между 3 узлами кластера
6.	✅ Верификация автоматического масштабирования при росте нагрузки
Кластер успешно обработал пиковую нагрузку, продемонстрировав эффективное распределение запросов и автоматическое масштабирование ресурсов.
