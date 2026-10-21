#import <Foundation/Foundation.h>
#import <IJSVG/IJSVG.h>
#import <mach/mach_time.h>
#import <pthread.h>
#import <sys/resource.h>

typedef struct {
    const char* path;
    size_t side;
    dispatch_semaphore_t ready;
    dispatch_semaphore_t go;
    uint64_t start, loaded, parsed, finished;
    CGImageRef image;
} Job;

static double milliseconds(uint64_t start, uint64_t end)
{
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    return (double)(end - start) * info.numer / info.denom / 1e6;
}

static void* render(void* pointer)
{
    Job* job = pointer;
    @autoreleasepool {
        dispatch_semaphore_signal(job->ready);
        dispatch_semaphore_wait(job->go, DISPATCH_TIME_FOREVER);
        job->start = mach_continuous_time();
        NSData* source = [NSData dataWithContentsOfFile:@(job->path)];
        job->loaded = mach_continuous_time();
        IJSVGParser* parser = [[IJSVGParser alloc] initWithSVGData:source fileURL:nil error:nil];
        IJSVGRootNode* root = [parser rootNodeWithSize:CGSizeZero];
        IJSVG* svg = root ? [[IJSVG alloc] initWithRootNode:root] : nil;
        job->parsed = mach_continuous_time();
        job->image = [svg newCGImageRefWithSize:CGSizeMake(job->side, job->side) flipped:NO error:nil];
        job->finished = mach_continuous_time();
    }
    return NULL;
}

int main(int argc, const char** argv)
{
    @autoreleasepool {
        if (argc != 5) {
            return 1;
        }
        int repeats = atoi(argv[1]), count = atoi(argv[2]), side = atoi(argv[3]);
        if (count < 1 || count > 32 || repeats < 1 || side < 1) {
            return 1;
        }
        printf("run,worker,load_ms,parse_ms,render_ms,completion_ms,batch_ms,peak_rss_bytes,pixel_hash\n");

        // Report the first batch in the process as run 0. Subsequent runs still
        // load, parse and render fresh SVG instances without cached redraws.
        for (int run = 0; run <= repeats; run++) {
            Job jobs[32] = { 0 };
            pthread_t threads[32];
            dispatch_semaphore_t ready = dispatch_semaphore_create(0);
            dispatch_semaphore_t go = dispatch_semaphore_create(0);
            for (int i = 0; i < count; i++) {
                jobs[i].path = argv[4];
                jobs[i].side = side;
                jobs[i].ready = ready;
                jobs[i].go = go;
                if (pthread_create(&threads[i], NULL, render, &jobs[i])) {
                    return 2;
                }
            }
            for (int i = 0; i < count; i++) {
                dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER);
            }
            uint64_t start = mach_continuous_time(), end = start;
            for (int i = 0; i < count; i++) {
                dispatch_semaphore_signal(go);
            }
            for (int i = 0; i < count; i++) {
                pthread_join(threads[i], NULL);
                if (!jobs[i].image) {
                    return 3;
                }
                end = MAX(end, jobs[i].finished);
            }
            struct rusage usage;
            getrusage(RUSAGE_SELF, &usage);

            // Verify only after every timed render has finished.
            for (int i = 0; i < count; i++) {
                Job* job = &jobs[i];
                CFDataRef pixels = CGDataProviderCopyData(CGImageGetDataProvider(job->image));
                const UInt8* bytes = CFDataGetBytePtr(pixels);
                CFIndex length = CFDataGetLength(pixels);
                uint64_t hash = UINT64_C(14695981039346656037);
                for (CFIndex j = 0; j < length; j++) {
                    hash = (hash ^ bytes[j]) * UINT64_C(1099511628211);
                }
                CFRelease(pixels);
                printf("%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%ld,%016llx\n", run, i,
                    milliseconds(job->start, job->loaded), milliseconds(job->loaded, job->parsed),
                    milliseconds(job->parsed, job->finished), milliseconds(start, job->finished),
                    milliseconds(start, end), usage.ru_maxrss, (unsigned long long)hash);
                CGImageRelease(job->image);
            }
            fflush(stdout);
        }
    }
    return 0;
}
