import type {
  ProtectedJobResponse,
  ProtectedJobStatus,
  TestDataClassificationRequest,
  TestTextExtractionRequest
} from '@purview/contracts';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '';

export async function runTestTextExtraction(
  accessToken: string,
  request: TestTextExtractionRequest
): Promise<ProtectedJobResponse> {
  const response = await fetch(`${API_BASE}/api/v1/jobs/test-text-extraction`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      tenant_id: request.tenantId,
      file_name: request.fileName,
      text_sample: request.textSample
    })
  });

  if (!response.ok) {
    throw new Error('Unable to queue Test-TextExtraction job');
  }

  return (await response.json()) as ProtectedJobResponse;
}

export async function runTestDataClassification(
  accessToken: string,
  request: TestDataClassificationRequest
): Promise<ProtectedJobResponse> {
  const response = await fetch(`${API_BASE}/api/v1/jobs/test-data-classification`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      tenant_id: request.tenantId,
      text_sample: request.textSample,
      expected_labels: request.expectedLabels
    })
  });

  if (!response.ok) {
    throw new Error('Unable to queue Test-DataClassification job');
  }

  return (await response.json()) as ProtectedJobResponse;
}

export async function fetchJobStatus(accessToken: string, jobId: string): Promise<ProtectedJobStatus> {
  const response = await fetch(`${API_BASE}/api/v1/jobs/${jobId}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`
    }
  });

  if (!response.ok) {
    throw new Error('Unable to fetch job status');
  }

  return (await response.json()) as ProtectedJobStatus;
}
