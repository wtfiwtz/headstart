module Tenant
  module ExpressBullMQHandler
    def initialize_bullmq_config(config)
      @batch_jobs = config[:batch_jobs] || []
      @redis_config = config[:redis_config] || {
        host: "localhost",
        port: 6379
      }
      @bullmq_config = config[:bullmq_config] || {
        prefix: "bull",
        concurrency: 1,
        limiter: {
          max: 100,
          duration: 5000
        }
      }
    end
    
    def generate_bullmq_setup
      log_info("Generating BullMQ setup")
      
      # Skip if no batch jobs are defined
      if @batch_jobs.empty?
        log_info("No batch jobs defined, skipping BullMQ setup")
        return
      end
      
      # Determine base path based on language
      base_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src" : "#{@express_path}/src"
      
      # Create directories
      FileUtils.mkdir_p("#{base_path}/jobs")
      FileUtils.mkdir_p("#{base_path}/workers")
      
      # Add BullMQ dependencies to package.json
      add_bullmq_dependencies
      
      # Generate BullMQ configuration
      generate_bullmq_config(base_path)
      
      # Generate job queues
      generate_job_queues(base_path)
      
      # Generate workers
      generate_workers(base_path)
      
      # Generate job processors
      generate_job_processors(base_path)
      
      # Update app.js to include BullMQ setup
      update_app_with_bullmq
      
      log_info("BullMQ setup generated")
    end
    
    def add_bullmq_dependencies
      log_info("Adding BullMQ dependencies")
      
      # Read package.json
      package_json_path = "#{@express_path}/package.json"
      package_json = JSON.parse(File.read(package_json_path))
      
      # Add dependencies
      package_json["dependencies"] ||= {}
      package_json["dependencies"]["bullmq"] = "^4.12.4"
      package_json["dependencies"]["ioredis"] = "^5.3.2"
      package_json["dependencies"]["uuid"] = "^9.0.1"
      
      # Add dev dependencies for TypeScript if needed
      if @language.to_s.downcase == "typescript"
        package_json["devDependencies"] ||= {}
        package_json["devDependencies"]["@types/bullmq"] = "^4.2.0"
        package_json["devDependencies"]["@types/ioredis"] = "^5.0.0"
        package_json["devDependencies"]["@types/uuid"] = "^9.0.2"
      end
      
      # Write updated package.json
      File.write(package_json_path, JSON.pretty_generate(package_json))
      
      log_info("BullMQ dependencies added")
    end
    
    def generate_bullmq_config(base_path)
      log_info("Generating BullMQ configuration")
      
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      
      # Create config file
      if @language.to_s.downcase == "typescript"
        config_content = <<~TS
          import { Queue, Worker, QueueScheduler, ConnectionOptions, QueueOptions, WorkerOptions, QueueSchedulerOptions } from 'bullmq';
          import IORedis from 'ioredis';

          // Redis connection
          const connection = new IORedis({
            host: process.env.REDIS_HOST || '#{@redis_config[:host]}',
            port: parseInt(process.env.REDIS_PORT || '#{@redis_config[:port]}', 10),
            maxRetriesPerRequest: null,
          });

          // Default queue options
          const defaultQueueOptions: QueueOptions = {
            connection,
            prefix: process.env.BULL_PREFIX || '#{@bullmq_config[:prefix]}',
          };

          // Default worker options
          const defaultWorkerOptions: WorkerOptions = {
            connection,
            prefix: process.env.BULL_PREFIX || '#{@bullmq_config[:prefix]}',
            concurrency: parseInt(process.env.BULL_CONCURRENCY || '#{@bullmq_config[:concurrency]}', 10),
            limiter: {
              max: parseInt(process.env.BULL_LIMITER_MAX || '#{@bullmq_config[:limiter][:max]}', 10),
              duration: parseInt(process.env.BULL_LIMITER_DURATION || '#{@bullmq_config[:limiter][:duration]}', 10),
            },
          };

          // Create a queue
          const createQueue = <T = any, R = any>(name: string, options: QueueOptions = {}): Queue<T, R> => {
            return new Queue<T, R>(name, {
              ...defaultQueueOptions,
              ...options,
            });
          };

          // Create a worker
          const createWorker = <T = any, R = any>(name: string, processor: (job: any) => Promise<R>, options: WorkerOptions = {}): Worker<T, R> => {
            return new Worker<T, R>(name, processor, {
              ...defaultWorkerOptions,
              ...options,
            });
          };

          // Create a queue scheduler
          const createScheduler = (name: string, options: QueueSchedulerOptions = {}): QueueScheduler => {
            return new QueueScheduler(name, {
              connection,
              prefix: process.env.BULL_PREFIX || '#{@bullmq_config[:prefix]}',
              ...options,
            });
          };

          export {
            connection,
            createQueue,
            createWorker,
            createScheduler,
          };
        TS
      else
        config_content = <<~JS
          const { Queue, Worker, QueueScheduler } = require('bullmq');
          const IORedis = require('ioredis');

          // Redis connection
          const connection = new IORedis({
            host: process.env.REDIS_HOST || '#{@redis_config[:host]}',
            port: process.env.REDIS_PORT || #{@redis_config[:port]},
            maxRetriesPerRequest: null,
          });

          // Default queue options
          const defaultQueueOptions = {
            connection,
            prefix: process.env.BULL_PREFIX || '#{@bullmq_config[:prefix]}',
          };

          // Default worker options
          const defaultWorkerOptions = {
            connection,
            prefix: process.env.BULL_PREFIX || '#{@bullmq_config[:prefix]}',
            concurrency: process.env.BULL_CONCURRENCY || #{@bullmq_config[:concurrency]},
            limiter: {
              max: process.env.BULL_LIMITER_MAX || #{@bullmq_config[:limiter][:max]},
              duration: process.env.BULL_LIMITER_DURATION || #{@bullmq_config[:limiter][:duration]},
            },
          };

          // Create a queue
          const createQueue = (name, options = {}) => {
            return new Queue(name, {
              ...defaultQueueOptions,
              ...options,
            });
          };

          // Create a worker
          const createWorker = (name, processor, options = {}) => {
            return new Worker(name, processor, {
              ...defaultWorkerOptions,
              ...options,
            });
          };

          // Create a queue scheduler
          const createScheduler = (name, options = {}) => {
            return new QueueScheduler(name, {
              connection,
              prefix: process.env.BULL_PREFIX || '#{@bullmq_config[:prefix]}',
              ...options,
            });
          };

          module.exports = {
            connection,
            createQueue,
            createWorker,
            createScheduler,
          };
        JS
      end
      
      File.write("#{base_path}/jobs/bullmq-config.#{file_ext}", config_content)
      
      log_info("BullMQ configuration generated")
    end
    
    def generate_job_queues(base_path)
      log_info("Generating job queues")
      
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      
      # Create queues file
      if @language.to_s.downcase == "typescript"
        queues_content = <<~TS
          import { Queue } from 'bullmq';
          import { createQueue } from './bullmq-config';

          // Define job data interfaces
          #{@batch_jobs.map do |job|
            <<~INTERFACE
              export interface #{job[:name].capitalize}JobData {
                // Define your job data structure here
                [key: string]: any;
              }
            INTERFACE
          end.join("\n")}

          // Create queues for each job type
          #{@batch_jobs.map { |job| "const #{job[:name]}Queue = createQueue<#{job[:name].capitalize}JobData>('#{job[:name]}');" }.join("\n")}

          export {
            #{@batch_jobs.map { |job| "#{job[:name]}Queue," }.join("\n  ")}
          };
        TS
      else
        queues_content = <<~JS
          const { createQueue } = require('./bullmq-config');

          // Create queues for each job type
          #{@batch_jobs.map { |job| "const #{job[:name]}Queue = createQueue('#{job[:name]}');" }.join("\n")}

          module.exports = {
            #{@batch_jobs.map { |job| "#{job[:name]}Queue," }.join("\n  ")}
          };
        JS
      end
      
      File.write("#{base_path}/jobs/queues.#{file_ext}", queues_content)
      
      log_info("Job queues generated")
    end
    
    def generate_workers(base_path)
      log_info("Generating workers")
      
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      
      # Create workers file
      if @language.to_s.downcase == "typescript"
        workers_content = <<~TS
          import path from 'path';
          import { Job } from 'bullmq';
          import { createWorker, createScheduler } from '../jobs/bullmq-config';
          #{@batch_jobs.map { |job| "import #{job[:name]}Processor from './processors/#{job[:name]}';" }.join("\n")}
          import { #{@batch_jobs.map { |job| "#{job[:name].capitalize}JobData" }.join(", ")} } from '../jobs/queues';

          // Create workers for each job type
          #{@batch_jobs.map { |job| "const #{job[:name]}Worker = createWorker<#{job[:name].capitalize}JobData>('#{job[:name]}', #{job[:name]}Processor);" }.join("\n")}

          // Create schedulers for each job type
          #{@batch_jobs.map { |job| "const #{job[:name]}Scheduler = createScheduler('#{job[:name]}');" }.join("\n")}

          // Handle worker events
          #{@batch_jobs.map do |job|
            <<~WORKER_EVENTS
              #{job[:name]}Worker.on('completed', (job: Job) => {
                console.log(`Job ${job.id} in queue #{job[:name]} completed`);
              });

              #{job[:name]}Worker.on('failed', (job: Job, err: Error) => {
                console.error(`Job ${job.id} in queue #{job[:name]} failed with error: ${err.message}`);
              });
            WORKER_EVENTS
          end.join("\n")}

          process.on('SIGTERM', async () => {
            console.log('Closing workers...');
            #{@batch_jobs.map { |job| "await #{job[:name]}Worker.close();" }.join("\n  ")}
            process.exit(0);
          });

          export {
            #{@batch_jobs.map { |job| "#{job[:name]}Worker," }.join("\n  ")}
          };
        TS
      else
        workers_content = <<~JS
          const path = require('path');
          const { createWorker, createScheduler } = require('../jobs/bullmq-config');

          // Create workers for each job type
          #{@batch_jobs.map { |job| "const #{job[:name]}Worker = createWorker('#{job[:name]}', require(path.join(__dirname, 'processors', '#{job[:name]}')));" }.join("\n")}

          // Create schedulers for each job type
          #{@batch_jobs.map { |job| "const #{job[:name]}Scheduler = createScheduler('#{job[:name]}');" }.join("\n")}

          // Handle worker events
          #{@batch_jobs.map do |job|
            <<~WORKER_EVENTS
              #{job[:name]}Worker.on('completed', (job) => {
                console.log(`Job ${job.id} in queue #{job[:name]} completed`);
              });

              #{job[:name]}Worker.on('failed', (job, err) => {
                console.error(`Job ${job.id} in queue #{job[:name]} failed with error: ${err.message}`);
              });
            WORKER_EVENTS
          end.join("\n")}

          process.on('SIGTERM', async () => {
            console.log('Closing workers...');
            #{@batch_jobs.map { |job| "await #{job[:name]}Worker.close();" }.join("\n  ")}
            process.exit(0);
          });

          module.exports = {
            #{@batch_jobs.map { |job| "#{job[:name]}Worker," }.join("\n  ")}
          };
        JS
      end
      
      File.write("#{base_path}/workers/index.#{file_ext}", workers_content)
      
      log_info("Workers generated")
    end
    
    def generate_job_processors(base_path)
      log_info("Generating job processors")
      
      # Create processors directory
      FileUtils.mkdir_p("#{base_path}/workers/processors")
      
      # Determine file extension based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      
      # Generate processor for each job
      @batch_jobs.each do |job|
        if @language.to_s.downcase == "typescript"
          processor_content = <<~TS
            /**
             * Processor for #{job[:name]} jobs
             * #{job[:description] || "Processes #{job[:name]} tasks"}
             */
            import { Job } from 'bullmq';
            import { #{job[:name].capitalize}JobData } from '../../jobs/queues';

            const #{job[:name]}Processor = async (job: Job<#{job[:name].capitalize}JobData>): Promise<any> => {
              try {
                console.log(`Processing #{job[:name]} job ${job.id}`, job.data);
                
                // Simulate processing time
                await new Promise(resolve => setTimeout(resolve, #{job[:processing_time] || 1000}));
                
                // Update job progress
                await job.updateProgress(50);
                
                // Simulate more processing
                await new Promise(resolve => setTimeout(resolve, #{job[:processing_time] || 1000}));
                
                // Example result
                const result = {
                  jobId: job.id,
                  processed: true,
                  timestamp: new Date().toISOString(),
                  data: job.data
                };
                
                console.log(`Completed #{job[:name]} job ${job.id}`);
                
                return result;
              } catch (error) {
                console.error(`Error processing #{job[:name]} job ${job.id}:`, error);
                throw error;
              }
            };

            export default #{job[:name]}Processor;
          TS
        else
          processor_content = <<~JS
            /**
             * Processor for #{job[:name]} jobs
             * #{job[:description] || "Processes #{job[:name]} tasks"}
             */
            module.exports = async (job) => {
              try {
                console.log(`Processing #{job[:name]} job ${job.id}`, job.data);
                
                // Simulate processing time
                await new Promise(resolve => setTimeout(resolve, #{job[:processing_time] || 1000}));
                
                // Update job progress
                await job.updateProgress(50);
                
                // Simulate more processing
                await new Promise(resolve => setTimeout(resolve, #{job[:processing_time] || 1000}));
                
                // Example result
                const result = {
                  jobId: job.id,
                  processed: true,
                  timestamp: new Date().toISOString(),
                  data: job.data
                };
                
                console.log(`Completed #{job[:name]} job ${job.id}`);
                
                return result;
              } catch (error) {
                console.error(`Error processing #{job[:name]} job ${job.id}:`, error);
                throw error;
              }
            };
          JS
        end
        
        File.write("#{base_path}/workers/processors/#{job[:name]}.#{file_ext}", processor_content)
      end
      
      log_info("Job processors generated")
    end
    
    def update_app_with_bullmq
      log_info("Updating app with BullMQ routes")
      
      # Determine file extension and path based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      app_file = @language.to_s.downcase == "typescript" ? "#{@express_path}/src/app.#{file_ext}" : "#{@express_path}/app.#{file_ext}"
      
      # Generate job routes
      generate_job_routes
      
      # Read app.js content
      app_content = File.read(app_file)
      
      # Add import for job routes
      if @language.to_s.downcase == "typescript"
        import_statement = "import jobRoutes from './routes/job-routes';"
        
        # Find position to insert import
        last_import_position = app_content.rindex(/^import .+;$/m)
        if last_import_position
          last_import_end = app_content.index("\n", last_import_position) + 1
          app_content.insert(last_import_end, "#{import_statement}\n")
        end
      else
        require_statement = "const jobRoutes = require('./routes/job-routes');"
        
        # Find position to insert require
        last_require_position = app_content.rindex(/^const .+ = require\(.+\);$/m)
        if last_require_position
          last_require_end = app_content.index("\n", last_require_position) + 1
          app_content.insert(last_require_end, "#{require_statement}\n")
        end
      end
      
      # Add route usage
      route_usage = "app.use('/api/jobs', jobRoutes);"
      
      # Find position to insert route usage
      routes_marker = "// Routes"
      routes_position = app_content.index(routes_marker)
      if routes_position
        routes_end = app_content.index("\n", routes_position) + 1
        app_content.insert(routes_end, "#{route_usage}\n")
      end
      
      # Write updated content back to app.js
      File.write(app_file, app_content)
      
      log_info("App updated with BullMQ routes")
    end
    
    def generate_job_routes
      log_info("Generating job routes")
      
      # Determine file extension and path based on language
      file_ext = @language.to_s.downcase == "typescript" ? "ts" : "js"
      base_path = @language.to_s.downcase == "typescript" ? "#{@express_path}/src" : @express_path
      
      # Create routes directory if it doesn't exist
      FileUtils.mkdir_p("#{base_path}/routes")
      
      # Generate job routes file
      if @language.to_s.downcase == "typescript"
        routes_content = <<~TS
          import express, { Request, Response, Router } from 'express';
          import { v4 as uuidv4 } from 'uuid';
          import { #{@batch_jobs.map { |job| "#{job[:name]}Queue" }.join(", ")} } from '../jobs/queues';

          const router: Router = express.Router();

          // Get all job types
          router.get('/types', (req: Request, res: Response) => {
            res.json({
              jobTypes: [#{@batch_jobs.map { |job| "'#{job[:name]}'" }.join(", ")}]
            });
          });

          // Add a job to a queue
          router.post('/:jobType', async (req: Request, res: Response) => {
            const { jobType } = req.params;
            const jobData = req.body;
            
            try {
              let job;
              
              switch (jobType) {
                #{@batch_jobs.map do |job|
                  <<~CASE
                    case '#{job[:name]}':
                      job = await #{job[:name]}Queue.add(`#{job[:name]}-${uuidv4()}`, jobData, {
                        attempts: 3,
                        backoff: {
                          type: 'exponential',
                          delay: 1000
                        }
                      });
                      break;
                  CASE
                end.join("")}
                default:
                  return res.status(400).json({ error: `Unknown job type: ${jobType}` });
              }
              
              res.status(201).json({
                id: job.id,
                name: job.name,
                data: job.data,
                timestamp: new Date().toISOString()
              });
            } catch (error) {
              console.error(`Error adding job to ${jobType} queue:`, error);
              res.status(500).json({ error: 'Failed to add job to queue' });
            }
          });

          // Get job status
          router.get('/:jobType/:jobId', async (req: Request, res: Response) => {
            const { jobType, jobId } = req.params;
            
            try {
              let job;
              
              switch (jobType) {
                #{@batch_jobs.map do |job|
                  <<~CASE
                    case '#{job[:name]}':
                      job = await #{job[:name]}Queue.getJob(jobId);
                      break;
                  CASE
                end.join("")}
                default:
                  return res.status(400).json({ error: `Unknown job type: ${jobType}` });
              }
              
              if (!job) {
                return res.status(404).json({ error: 'Job not found' });
              }
              
              const state = await job.getState();
              
              res.json({
                id: job.id,
                name: job.name,
                data: job.data,
                state,
                progress: job.progress,
                timestamp: job.timestamp
              });
            } catch (error) {
              console.error(`Error getting job status for ${jobType}/${jobId}:`, error);
              res.status(500).json({ error: 'Failed to get job status' });
            }
          });

          export default router;
        TS
      else
        routes_content = <<~JS
          const express = require('express');
          const { v4: uuidv4 } = require('uuid');
          const { #{@batch_jobs.map { |job| "#{job[:name]}Queue" }.join(", ")} } = require('../jobs/queues');

          const router = express.Router();

          // Get all job types
          router.get('/types', (req, res) => {
            res.json({
              jobTypes: [#{@batch_jobs.map { |job| "'#{job[:name]}'" }.join(", ")}]
            });
          });

          // Add a job to a queue
          router.post('/:jobType', async (req, res) => {
            const { jobType } = req.params;
            const jobData = req.body;
            
            try {
              let job;
              
              switch (jobType) {
                #{@batch_jobs.map do |job|
                  <<~CASE
                    case '#{job[:name]}':
                      job = await #{job[:name]}Queue.add(`#{job[:name]}-${uuidv4()}`, jobData, {
                        attempts: 3,
                        backoff: {
                          type: 'exponential',
                          delay: 1000
                        }
                      });
                      break;
                  CASE
                end.join("")}
                default:
                  return res.status(400).json({ error: `Unknown job type: ${jobType}` });
              }
              
              res.status(201).json({
                id: job.id,
                name: job.name,
                data: job.data,
                timestamp: new Date().toISOString()
              });
            } catch (error) {
              console.error(`Error adding job to ${jobType} queue:`, error);
              res.status(500).json({ error: 'Failed to add job to queue' });
            }
          });

          // Get job status
          router.get('/:jobType/:jobId', async (req, res) => {
            const { jobType, jobId } = req.params;
            
            try {
              let job;
              
              switch (jobType) {
                #{@batch_jobs.map do |job|
                  <<~CASE
                    case '#{job[:name]}':
                      job = await #{job[:name]}Queue.getJob(jobId);
                      break;
                  CASE
                end.join("")}
                default:
                  return res.status(400).json({ error: `Unknown job type: ${jobType}` });
              }
              
              if (!job) {
                return res.status(404).json({ error: 'Job not found' });
              }
              
              const state = await job.getState();
              
              res.json({
                id: job.id,
                name: job.name,
                data: job.data,
                state,
                progress: job.progress,
                timestamp: job.timestamp
              });
            } catch (error) {
              console.error(`Error getting job status for ${jobType}/${jobId}:`, error);
              res.status(500).json({ error: 'Failed to get job status' });
            }
          });

          module.exports = router;
        JS
      end
      
      File.write("#{base_path}/routes/job-routes.#{file_ext}", routes_content)
      
      log_info("Job routes generated")
    end
  end
end 