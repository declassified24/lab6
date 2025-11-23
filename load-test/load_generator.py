import threading
import requests
import time
import random
import sys

class LoadGenerator:
    def __init__(self, target_url, num_threads=50, duration=600):
        self.target_url = target_url
        self.num_threads = num_threads
        self.duration = duration
        self.success_count = 0
        self.error_count = 0
        self.lock = threading.Lock()
        
    def worker(self, thread_id):
        end_time = time.time() + self.duration
        while time.time() < end_time:
            try:
                start_time = time.time()
                response = requests.get(self.target_url, timeout=5)
                latency = (time.time() - start_time) * 1000
                
                with self.lock:
                    if response.status_code == 200:
                        self.success_count += 1
                        print(f"Thread {thread_id}: OK - {response.status_code} - {latency:.2f}ms")
                    else:
                        self.error_count += 1
                        print(f"Thread {thread_id}: ERROR - {response.status_code}")
                        
            except Exception as e:
                with self.lock:
                    self.error_count += 1
                    print(f"Thread {thread_id}: EXCEPTION - {str(e)}")
            
            time.sleep(random.uniform(0.1, 0.3))
    
    def run(self):
        print(f"Starting load test with {self.num_threads} threads for {self.duration} seconds")
        threads = []
        
        for i in range(self.num_threads):
            thread = threading.Thread(target=self.worker, args=(i,))
            thread.daemon = True
            thread.start()
            threads.append(thread)
        
        # Мониторинг прогресса
        start_time = time.time()
        while time.time() - start_time < self.duration:
            time.sleep(5)
            total = self.success_count + self.error_count
            success_rate = (self.success_count / total * 100) if total > 0 else 0
            print(f"Progress: {time.time() - start_time:.1f}s | Success: {self.success_count} | Errors: {self.error_count} | Rate: {success_rate:.1f}%")
        
        print(f"\nLoad test completed:")
        print(f"Total requests: {self.success_count + self.error_count}")
        print(f"Successful: {self.success_count}")
        print(f"Errors: {self.error_count}")
        print(f"Success rate: {(self.success_count/(self.success_count + self.error_count)*100):.1f}%")

if __name__ == "__main__":
    target_url = "http://127.0.0.1"  # LoadBalancer URL
    generator = LoadGenerator(target_url, num_threads=50, duration=600)
    generator.run()
