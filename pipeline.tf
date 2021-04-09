resource "aws_codebuild_project" "tf-plan" {
  name          = "tf-cicd-plan"
  description   = "plan stage for terraform"
  service_role  = aws_iam_role.tf-codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:0.14.4"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential {
        credential = var.dockerhub_credentials
        credential_provider = "SECRETS_MANAGER"
    }
  }

 source {
    type   = "CODEPIPELINE"
    buildspec = file("buildspec/plan-buildspec.yml")
 }
 
}

resource "aws_codebuild_project" "tf-apply" {
  name          = "tf-cicd-apply"
  description   = "Apply stage for terraform"
  service_role  = aws_iam_role.tf-codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:0.14.4"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential {
        credential = var.dockerhub_credentials
        credential_provider = "SECRETS_MANAGER"
    }
  }
  source  {
    type   = "CODEPIPELINE"
    buildspec = file("buildspec/apply-buildspec.yml")
  }
}

# Build the pipeline
resource "aws_codepipeline" "cicd-pipeline"{
  name     = "tf-cicd"
  role_arn = aws_iam_role.tf-codepipeline-role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline-artifact.id
    type     = "S3"
  }
    
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          =  "1"
      input_artifacts = []
      output_artifacts = [
        "SourceArtifact",
      ]
      configuration = {
        ConnectionArn    = var.codestar_connector_credentials
        FullRepositoryId = "Kenmakhanu/aws-cicd-pipeline"
        BranchName       = "main"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceArtifact",]
      version          = "1"
      output_artifacts = ["PlanArtifact",]
      configuration = {
        ProjectName = "tf-cicd-plan"
      }
    }
  }

  stage {
    name = "Apply"

    action {
      name            = "Build"
      category        = "Build"
      provider        = "CodeBuild"
      owner            = "AWS"
      input_artifacts = ["SourceArtifact",]
      version         = "1"
      configuration = {
        ProjectName    = "tf-cicd-apply"
        
      }
    }
  }
  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
        BucketName  = aws_s3_bucket.codepipeline-artifact.id
        Extract     = "true"
      }
     # input_artifacts = [
      #  "PlanArtifact",
     # ]
      name             = "Deploy"
      output_artifacts = []
      owner            = "AWS"
      provider         = "S3"
      run_order        = 1
      version          = "1"
    }
  }
}

