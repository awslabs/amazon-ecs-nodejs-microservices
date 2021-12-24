aws cloudformation deploy \
   --template-file infrastructure/ecs.yml \
   --region ap-southeast-2 \
   --stack-name BreakTheMonolith-Demo \
   --capabilities CAPABILITY_NAMED_IAM
