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
