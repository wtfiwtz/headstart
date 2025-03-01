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
      
      # Create directories
      FileUtils.mkdir_p("#{@express_path}/src/jobs")
      FileUtils.mkdir_p("#{@express_path}/src/workers")
      
      # Add BullMQ dependencies to package.json
      add_bullmq_dependencies
      
      # Generate BullMQ configuration
      generate_bullmq_config
      
      # Generate job queues
      generate_job_queues
      
      # Generate workers
      generate_workers
      
      # Generate job processors
      generate_job_processors
      
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
      
      # Write updated package.json
      File.write(package_json_path, JSON.pretty_generate(package_json))
      
      log_info("BullMQ dependencies added")
    end
    
    def generate_bullmq_config
      log_info("Generating BullMQ configuration")
      
      # Create config file
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
      
      File.write("#{@express_path}/src/jobs/bullmq-config.js", config_content)
      
      log_info("BullMQ configuration generated")
    end
    
    def generate_job_queues
      log_info("Generating job queues")
      
      # Create queues file
      queues_content = <<~JS
        const { createQueue } = require('./bullmq-config');

        // Create queues for each job type
        #{@batch_jobs.map { |job| "const #{job[:name]}Queue = createQueue('#{job[:name]}');" }.join("\n")}

        module.exports = {
          #{@batch_jobs.map { |job| "#{job[:name]}Queue," }.join("\n  ")}
        };
      JS
      
      File.write("#{@express_path}/src/jobs/queues.js", queues_content)
      
      log_info("Job queues generated")
    end
    
    def generate_workers
      log_info("Generating workers")
      
      # Create workers file
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
      
      File.write("#{@express_path}/src/workers/index.js", workers_content)
      
      log_info("Workers generated")
    end
    
    def generate_job_processors
      log_info("Generating job processors")
      
      # Create processors directory
      FileUtils.mkdir_p("#{@express_path}/src/workers/processors")
      
      # Generate processor for each job
      @batch_jobs.each do |job|
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
        
        File.write("#{@express_path}/src/workers/processors/#{job[:name]}.js", processor_content)
      end
      
      log_info("Job processors generated")
    end
    
    def update_app_with_bullmq
      log_info("Updating app.js with BullMQ setup")
      
      # Read app.js
      app_js_path = "#{@express_path}/src/app.js"
      app_js = File.read(app_js_path)
      
      # Add BullMQ routes
      bullmq_routes = <<~JS

        // BullMQ job routes
        const jobRoutes = require('./routes/jobs');
        app.use('/api/jobs', jobRoutes);
      JS
      
      # Add BullMQ routes to app.js
      app_js.gsub!(/app\.use\('\/api', apiRouter\);/, "app.use('/api', apiRouter);#{bullmq_routes}")
      
      # Write updated app.js
      File.write(app_js_path, app_js)
      
      # Create job routes
      generate_job_routes
      
      log_info("app.js updated with BullMQ setup")
    end
    
    def generate_job_routes
      log_info("Generating job routes")
      
      # Create routes file
      routes_content = <<~JS
        const express = require('express');
        const router = express.Router();
        const { v4: uuidv4 } = require('uuid');
        const {
          #{@batch_jobs.map { |job| "#{job[:name]}Queue," }.join("\n  ")}
        } = require('../jobs/queues');

        /**
         * @swagger
         * /api/jobs:
         *   get:
         *     summary: Get all job queues
         *     tags: [Jobs]
         *     responses:
         *       200:
         *         description: List of available job queues
         */
        router.get('/', (req, res) => {
          res.json({
            queues: [
              #{@batch_jobs.map { |job| "{ name: '#{job[:name]}', description: '#{job[:description] || "Processes #{job[:name]} tasks"}' }" }.join(",\n              ")}
            ]
          });
        });

        #{@batch_jobs.map do |job|
          <<~JOB_ROUTE
            /**
             * @swagger
             * /api/jobs/#{job[:name]}:
             *   post:
             *     summary: Add a new #{job[:name]} job to the queue
             *     tags: [Jobs]
             *     requestBody:
             *       required: true
             *       content:
             *         application/json:
             *           schema:
             *             type: object
             *     responses:
             *       200:
             *         description: Job added to queue
             */
            router.post('/#{job[:name]}', async (req, res) => {
              try {
                const jobId = uuidv4();
                const jobData = {
                  id: jobId,
                  ...req.body,
                  createdAt: new Date().toISOString()
                };
                
                const job = await #{job[:name]}Queue.add('#{job[:name]}', jobData, {
                  jobId,
                  removeOnComplete: false,
                  removeOnFail: false
                });
                
                res.json({
                  success: true,
                  jobId: job.id,
                  message: '#{job[:name].capitalize} job added to queue'
                });
              } catch (error) {
                console.error('Error adding job to queue:', error);
                res.status(500).json({
                  success: false,
                  message: 'Error adding job to queue',
                  error: error.message
                });
              }
            });

            /**
             * @swagger
             * /api/jobs/#{job[:name]}/{id}:
             *   get:
             *     summary: Get #{job[:name]} job status
             *     tags: [Jobs]
             *     parameters:
             *       - in: path
             *         name: id
             *         required: true
             *         schema:
             *           type: string
             *     responses:
             *       200:
             *         description: Job status
             */
            router.get('/#{job[:name]}/:id', async (req, res) => {
              try {
                const job = await #{job[:name]}Queue.getJob(req.params.id);
                
                if (!job) {
                  return res.status(404).json({
                    success: false,
                    message: 'Job not found'
                  });
                }
                
                const state = await job.getState();
                const progress = job._progress;
                const result = job.returnvalue;
                
                res.json({
                  success: true,
                  job: {
                    id: job.id,
                    data: job.data,
                    state,
                    progress,
                    result,
                    createdAt: job.timestamp ? new Date(job.timestamp).toISOString() : null,
                    finishedAt: job.finishedOn ? new Date(job.finishedOn).toISOString() : null,
                    processedAt: job.processedOn ? new Date(job.processedOn).toISOString() : null
                  }
                });
              } catch (error) {
                console.error('Error getting job status:', error);
                res.status(500).json({
                  success: false,
                  message: 'Error getting job status',
                  error: error.message
                });
              }
            });
          JOB_ROUTE
        end.join("\n")}

        module.exports = router;
      JS
      
      # Create routes directory if it doesn't exist
      FileUtils.mkdir_p("#{@express_path}/src/routes")
      
      # Write routes file
      File.write("#{@express_path}/src/routes/jobs.js", routes_content)
      
      log_info("Job routes generated")
    end
  end
end 