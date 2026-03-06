export type JobType =
  | 'TEST_TEXT_EXTRACTION'
  | 'TEST_DATA_CLASSIFICATION'
  | 'GET_DLP_POLICIES';

export type JobRequest = {
  tenantId: string;
  jobType: JobType;
  accessToken: string;
  payload: Record<string, unknown>;
};

export type TestTextExtractionRequest = {
  tenantId: string;
  fileName: string;
  textSample: string;
};

export type TestDataClassificationRequest = {
  tenantId: string;
  textSample: string;
  expectedLabels: string[];
};

export type ProtectedJobResponse = {
  jobId: string;
  status: 'QUEUED';
  jobType: 'TEST_TEXT_EXTRACTION' | 'TEST_DATA_CLASSIFICATION';
};

export type ProtectedJobStatus = {
  jobId: string;
  tenantId: string;
  jobType: JobType;
  status: string;
  result: Record<string, unknown> | null;
};
