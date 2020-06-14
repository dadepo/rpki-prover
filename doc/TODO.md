+ implement resource set
+ extract SIA from certificates
+ do validation concurrently 

+ register new publication points while validating

+ "updateStatuses" in the bootstrap is wrong
+ add "I'm going to take care of this new repo" set to the top-down context

+ fix flaky behavior of the top-down
+ Count validated objects, compare with the others
+ Save VRPs somewhere, compare with the others (the same as routinator)
+ Fix "thread blocked indefinitely in an STM transaction"
+ Serialise VRPs incrementally in a separate thread.
+ Save validation errors/warnings while traversing the tree
+ Calculated hashed from the raw input, compare first and only then parse further (NO)
+ Fix MDB_BAD_VALSIZE, but first associate VRs with a timestamp
+ Fix broken tree traversal (Word32 -> Int32 was a bad idea)
+ Add timing of the main building blocks
+ Make WorldVersion more precise, update it only periodically and at proper moments
+ Add version storage and connect versions with VRPs and other stuff
+ Have a cache directory (.rpki-data (tals, lmsb, rsync, tmp))
+ Download TA cert by HTTPS 
+ Fix RRDP so that it uses deltas properly
+ Add tests for repository storage


---------------------------------------------------------------------------

- Relationship between ExceptT, forM and channles -- it's all can be done better only with exceptions.
- RRDP transaction must roll back in case of an error
- Fix txConsumeFold for forM :: ExceptT a ... -> 
- Delta processing can result in much bigger heap than snaphiost processing? fix it if that's the case.
- Have full path from the top repoistory to all the delegates ones in the VContext.
- add 'bootlneck' implementation as 'minimum of two bottlnecks at any moment'
- it looks like validCount number is flaky and changes depending on (check it)
- Add periodic re-validation
- Clean up objects that are not touched by validations or not touched by repository downloads
- Clean up old VRPs 
- Figure out how to classify "successful" validation and unsuccessful one to update the VRPs

- Read config and CLI options
- Reuse work, use a global pool of asyncs and attach multiple waiters to them.
- Refactor the parallel two-thread stuff to use streaming

- Gather stats on hjow much objects are updated/deleted in delta/snapshot updates to make better 
  choices when to download one of another.

- Lock the ".rpki" directory (or whatever is used instead) to avoid multiple copies of the same thing?

- SLURM (store a json file? it's not very effient in acse of AS0 in SLURM, so think about something 
  more scalable, binary serialisation, etc.)

- Do not save objects as one big transaction, it's not going to be a problem to save smaller chunks of objects, but will not lock the whole DB for seconds.
- Have more general framework for "thread that read from the channel and does stuff", it's repeating all over the place.

- Keep in LMDB only the necessary part of an object after checking it's signature.
- Review the validation and check if everything is according to the RFCs (time, digests, etc.)



- use co-log-concurrent
- refactor roTx/rwTx machinery so that rwTx accept both RO/RW handlers



Features to implement:
- Explain where broken stuff comes from
- 